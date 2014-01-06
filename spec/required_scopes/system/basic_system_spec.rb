require 'required_scopes'
require 'required_scopes/helpers/database_helper'
require 'required_scopes/helpers/system_helpers'

require 'pry'

describe "RequiredScopes basic operations" do
  include RequiredScopes::Helpers::SystemHelpers

  before :each do
    @dh = RequiredScopes::Helpers::DatabaseHelper.new
    @dh.setup_activerecord!

    create_standard_system_spec_tables!
    create_standard_system_spec_models!
    create_standard_system_spec_instances!
  end

  after :each do
    drop_standard_system_spec_tables!
  end

  def should_raise_missing_scopes(triggering_method, required, satisfied)
    e = result = nil

    begin
      result = yield
    rescue RequiredScopes::Errors::RequiredScopeCategoriesNotSatisfiedError => rscnse
      e = rscnse
    end

    raise "Expected a scopes-not-satisfied error, but got none" unless e

    expected_model_class = ::User

    e.class.should == RequiredScopes::Errors::RequiredScopeCategoriesNotSatisfiedError
    e.model_class.should == expected_model_class
    e.current_relation.should be
    e.current_relation.kind_of?(ActiveRecord::Relation).should be
    e.triggering_method.should == triggering_method
    e.required_categories.sort_by(&:to_s).should == required.sort_by(&:to_s)
    e.satisfied_categories.sort_by(&:to_s).should == satisfied.sort_by(&:to_s)

    expected_missing_categories = required - satisfied
    e.missing_categories.sort_by(&:to_s).should == expected_missing_categories.sort_by(&:to_s)

    e.message.should match(/#{expected_model_class.name}/)
    e.message.should match(/#{expected_missing_categories.sort_by(&:to_s).join(", ")}/)
  end

  context "with two required scope categories" do
    before :each do
      ::User.class_eval do
        must_scope_by :color, :taste

        scope :red, lambda { where(:favorite_color => 'red') }, :category => :color
        scope :green, lambda { where(:favorite_color => 'green') }, :category => :color

        scope :salty, lambda { where(:favorite_taste => 'salty') }, :category => :taste
        scope :sweet, lambda { where(:favorite_taste => 'sweet') }, :category => :taste

        scope :red_and_salty, lambda { where(:favorite_color => 'red', :favorite_taste => 'salty') }, :categories => [ :color, :taste ]
      end
    end

    describe "queries" do
      it "should raise if no categories are applied" do
        should_raise_missing_scopes(:exec_queries, [ :color, :taste ], [ ]) { ::User.all.to_a }
      end

      it "should raise if only one category is applied" do
        should_raise_missing_scopes(:exec_queries, [ :color, :taste ], [ :color ]) { ::User.red.to_a }
      end

      it "should not raise if both categories are individually applied" do
        ::User.red.salty.to_a.should == [ @red_salty ]
      end

      it "should not raise if both categories are satisfied by a single scope" do
        ::User.red_and_salty.to_a.should == [ @red_salty ]
      end

      it "should allow further qualifying the scopes, and in the middle" do
        ::User.where("name LIKE 'red%'").red.where("name LIKE '%salty'").salty.where("name LIKE '%d-s%'").to_a.should == [ @red_salty ]
        ::User.where("name LIKE 'green%'").red.salty.to_a.should == [ ]
        ::User.red.where("name LIKE '%sweet'").salty.to_a.should == [ ]
        ::User.red.salty.where("name LIKE '%sweet'").to_a.should == [ ]
      end

      it "should automatically have a scope that includes all of each category" do
        ::User.red.ignoring_taste.to_a.sort.should == [ @red_salty, @red_sweet ].sort
        ::User.ignoring_color.sweet.to_a.sort.should == [ @red_sweet, @green_sweet, @blue_sweet ].sort
      end

      it "should skip all checks on #unscoped" do
        ::User.unscoped.to_a.sort.should == [ @red_salty, @red_sweet, @green_salty, @green_sweet, @blue_salty, @blue_sweet ].sort
      end

      it "should skip all checks on #unscoped, and persist through other scopes" do
        ::User.unscoped.red.to_a.sort.should == [ @red_salty, @red_sweet ].sort
      end

      it "should skip all checks inside an #unscoped block" do
        ::User.unscoped do
          ::User.all.to_a.sort.should == [ @red_salty, @red_sweet, @green_salty, @green_sweet, @blue_salty, @blue_sweet ].sort
        end
      end

      it "should allow manually saying that categories are satisfied" do
        ::User.red.satisfying_category(:taste).to_a.sort.should == [ @red_salty, @red_sweet ].to_a
        ::User.satisfying_category(:color).sweet.to_a.sort.should == [ @red_sweet, @green_sweet, @blue_sweet ].to_a
        ::User.satisfying_categories(:color, :taste).to_a.sort.should ==
          [ @red_sweet, @green_sweet, @blue_sweet, @red_salty, @green_salty, @blue_salty ].to_a.sort
        ::User.satisfying_categories(:color, :taste).sweet.to_a.sort.should ==
          [ @red_sweet, @green_sweet, @blue_sweet ].to_a.sort
      end

      it "should allow saying that categories are satisfied in a class method, in any position" do
        ::User.class_eval do
          class << self
            def red_and_green
              satisfying_category(:color).where(:favorite_color => %w{red green})
            end

            def green_and_blue
              where(:favorite_color => %w{green blue}).satisfying_category(:color)
            end

            def just_blue
              where(:favorite_color => %w{red blue}).satisfying_category(:color).where(:favorite_color => %w{blue green})
            end
          end
        end

        ::User.red_and_green.salty.to_a.sort.should == [ @red_salty, @green_salty ].sort
        ::User.green_and_blue.salty.to_a.sort.should == [ @green_salty, @blue_salty ].sort
        ::User.just_blue.salty.to_a.sort.should == [ @blue_salty ].sort
      end
    end

  # Methods:
  #
  #   - Relation base class:
  #       N #new(*args, &block) (creates new record in memory from relation)
  #       N #create(*args, &block), #create! (creates new record in database from relation)
  #         #first_or_create(attributes = nil, &block), #first_or_create!, #first_or_initialize
  #         #find_or_create_by(attributes, &block), #find_or_create_by!, #find_or_initialize_by
  #       N #explain()
  #         #to_a()
  #         #as_json()
  #         #size() (i.e., #count)
  #         #empty?()
  #         #any?()
  #         #many?()
  #         #scoping(&block) (should NEVER raise, but should persist through the block)
  #         #update_all(updates)
  #         #update(id, attributes)
  #         #destroy_all(conditions = nil)
  #         #destroy(id)
  #         #delete_all(conditions = nil)
  #         #delete(id_or_array)
  #         #load()
  #         #reload()
  #       N #reset
  #       N #to_sql
  #
  #   - FinderMethods:
  #         #find(*args, &block)
  #         #find_by(*args), #find_by!(*args)
  #         #take(limit = nil), #take!
  #         #first(limit = nil), #first!
  #         #last(limit = nil), #last!
  #         #exists?(conditions = :none)
  #
  #   - Calculations:
  #         #count(column_name = nil, options = {})
  #         #average(column_name, options = {})
  #         #minimum(column_name, options = {})
  #         #maximum(column_name, options = {})
  #         #sum(*args)
  #         #calculate(operation, column_name, options = {})
  #         #pluck(*column_names)
  #         #ids
  #
  #   - SpawnMethods:
  #       N #spawn
  #       N #merge(other), #merge!(other)
  #       N #except(*skips), #only(*onlies)
  #
  #   - QueryMethods:
  #       N #includes(*args), #includes!(*args)
  #       N #eager_load, #eager_load!
  #       N #preload(*args), #preload!(*args)
  #       N #references(*args), #references!(*args)
  #       N #select(*fields), #select!(*fields)
  #       N #group(*args), #group!(*args)
  #       N #order(*args), #order!(*args)
  #       N #reorder(*args), #reorder!(*args)
  #       N #unscope(*args), #unscope!(*args)
  #       N #joins(*args), #joins!(*args)
  #       N #bind(value), #bind!(value)
  #       N #where(opts = :chain, *rest), #where!(opts = :chain, *rest)
  #       N #having(opts, *rest), #having!(opts, *rest)
  #       N #limit(value), #limit!(value)
  #       N #offset(value), #offset!(value)
  #       N #lock(locks = true) ,#lock!(locks = true)
  #       N #none, #none!
  #       N #readonly(value = true), #readonly!(value = true)
  #       N #create_with(value), #create_with!(value)
  #       N #from(value, subquery_name = nil), #from!(value, subquery_name = nil)
  #       N #distinct(value = true), #distinct!(value = true)
  #       N #extending(*modules, &block), #extending!(*modules, &block)
  #       N #reverse_order, #reverse_order!
  #       N #arel, #build_arel
  #
  #    - Batches:
  #         #find_each(options = {})
  #         #find_in_batches(options = {})
  #
  #    - Explain:
  #       N #collecting_queries_for_explain()
  #       N #exec_explain(queries)
  #
  #    - Delegation:
  #         #to_xml, #to_yaml, #length, #collect, #map, #each, #all?, #include?, #to_ary, #to_a
  #       N #table_name, #quoted_table_name, #primary_key, #quoted_primary_key, #connection, #columns_hash

    class ShouldRaiseDescription
      attr_reader :description, :block

      def initialize(description, triggering_method, block)
        @description = description
        @triggering_method = triggering_method
        @block = block
      end

      def go!(spec, call_on, required, satisfied)
        spec.should_raise_missing_scopes(@triggering_method, required, satisfied) { @block.call(call_on) }
      end
    end

    class << self
      def srd(description, triggering_method, &block)
        ShouldRaiseDescription.new(description, triggering_method, block)
      end
    end

    class ActiveRecord::Base
      class << self
        def to_relation
          relation
        end
      end
    end

    class ActiveRecord::Relation
      def to_relation
        self
      end
    end

    describe "methods that should raise" do
      [
        # ActiveRecord::Relation
        srd(:first_or_create, :exec_queries) { |s| s.first_or_create(:name => 'some user') },
        srd(:first_or_create!, :exec_queries) { |s| s.first_or_create!(:name => 'some user') },
        srd(:first_or_initialize, :exec_queries) { |s| s.first_or_initialize(:name => 'some user') },
        srd(:find_or_create_by, :exec_queries) { |s| s.find_or_create_by(:name => 'some user') },
        srd(:find_or_create_by!, :exec_queries) { |s| s.find_or_create_by!(:name => 'some user') },
        srd(:find_or_initialize_by, :exec_queries) { |s| s.find_or_initialize_by(:name => 'some user') },
        srd(:to_a, :exec_queries) { |s| s.to_relation.to_a },
        srd(:explain, :exec_queries) { |s| s.to_relation.explain },
        srd(:as_json, :exec_queries) { |s| s.to_relation.as_json },
        srd(:size, :perform_calculation) { |s| s.to_relation.size },
        srd(:empty?, :perform_calculation) { |s| s.to_relation.empty? },
        srd(:any?, :perform_calculation) { |s| s.to_relation.any? },
        srd(:many?, :perform_calculation) { |s| s.to_relation.many? },
        srd(:scoping, :exec_queries) { |s| s.to_relation.scoping { ::User.all.to_a } },
        srd(:update_all, :update_all) { |s| s.update_all("name = 'foo'") },
        srd(:update, :exec_queries) { |s| s.update(::User.unscoped.first.id, :name => 'foo') },
        srd(:destroy_all, :exec_queries) { |s| s.destroy_all },
        srd(:destroy, :exec_queries) { |s| s.destroy(::User.unscoped.first.id) },
        srd(:delete_all, :delete_all) { |s| s.delete_all },
        srd(:delete, :delete_all) { |s| s.delete(::User.unscoped.first.id) },
        srd(:load, :exec_queries) { |s| s.to_relation.load },
        srd(:reload, :exec_queries) { |s| s.to_relation.reload },

        # ActiveRecord::Relation::FinderMethods
        srd(:find, :exec_queries) { |s| s.find(::User.unscoped.first.id) },
        srd(:find_by, :exec_queries) { |s| s.find_by(:name => 'User 1') },
        srd(:find_by!, :exec_queries) { |s| s.find_by!(:name => ::User.unscoped.first.name) },
        srd(:take, :exec_queries) { |s| s.take },
        srd(:take!, :exec_queries) { |s| s.take! },
        srd(:first, :exec_queries) { |s| s.first },
        srd(:first!, :exec_queries) { |s| s.first! },
        srd(:last, :exec_queries) { |s| s.last },
        srd(:last!, :exec_queries) { |s| s.last! },
        srd(:exists?, :exists?) { |s| s.exists? },

        # ActiveRecord::Relation::Calculations
        srd(:count, :perform_calculation) { |s| s.count },
        srd(:average, :perform_calculation) { |s| s.average("id") },
        srd(:minimum, :perform_calculation) { |s| s.minimum("id") },
        srd(:maximum, :perform_calculation) { |s| s.maximum("id") },
        srd(:sum, :perform_calculation) { |s| s.sum("id") },
        srd(:calculate, :perform_calculation) { |s| s.calculate("SUM", "id") },
        srd(:pluck, :pluck) { |s| s.pluck("name") },
        srd(:ids, :pluck) { |s| s.ids },

        # ActiveRecord::Relation::Batches
        srd(:find_each, :exec_queries) { |s| s.find_each { |o| } },
        srd(:find_in_batches, :exec_queries) { |s| s.find_in_batches { |b| } },

        # ActiveRecord::Relation::Delegation
        srd(:to_xml, :exec_queries) { |s| s.to_relation.to_xml },
        srd(:to_yaml, :exec_queries) { |s| s.to_relation.to_yaml },
        srd(:length, :exec_queries) { |s| s.to_relation.length },
        srd(:collect, :exec_queries) { |s| s.to_relation.collect(&:to_s) },
        srd(:map, :exec_queries) { |s| s.to_relation.map(&:to_s) },
        srd(:each, :exec_queries) { |s| s.to_relation.each(&:to_s) },
        srd(:all?, :exec_queries) { |s| s.to_relation.all?(&:to_s) },
        srd(:include?, :exec_queries) { |s| s.to_relation.include?('foo') },
        srd(:to_ary, :exec_queries) { |s| s.to_relation.to_ary },
        srd(:to_a, :exec_queries) { |s| s.to_relation.to_a }
      ].each do |srd_obj|
        describe "##{srd_obj.description}" do
          it "should raise when invoked on the base class" do
            srd_obj.go!(self, ::User, [ :color, :taste ], [ ])
          end

          it "should raise when invoked with just one scope" do
            srd_obj.go!(self, ::User.red, [ :color, :taste ], [ :color ])
            srd_obj.go!(self, ::User.salty, [ :color, :taste ], [ :taste ])
          end

          it "should not raise when invoked with both scopes" do
            srd_obj.block.call(::User.red.salty)
          end
        end
      end
    end

    class NoRaiseDescription
      attr_reader :description

      def initialize(description, block)
        @description = description
        @block = block
      end

      def go!(call_on)
        @block.call(call_on)
      end
    end

    class << self
      def nrd(description, &block)
        NoRaiseDescription.new(description, block)
      end
    end

    describe "methods that should not raise" do
      [
        # ActiveRecord::Relation
        nrd(:new) { |s| s.new },
        nrd(:create) { |s| s.create(:name => 'User 1') },
        nrd(:create!) { |s| s.create!(:name => 'User 1') },
        nrd(:scoping) { |s| s.to_relation.scoping { } },
        nrd(:reset) { |s| s.to_relation.reset },
        nrd(:to_sql) { |s| s.to_relation.to_sql },

        # ActiveRecord::Relation::SpawnMethods
        nrd(:spawn) { |s| s.to_relation.spawn },
        nrd(:merge) { |s| s.to_relation.merge(s.where(:name => 'User 1')) },
        nrd(:merge!) { |s| s.to_relation.merge!(s.where(:name => 'User 1')) },
        nrd(:except) { |s| s.to_relation.except(:order) },
        nrd(:only) { |s| s.to_relation.only(:order) },

        # ActiveRecord::Relation::QueryMethods
        nrd(:includes) { |s| s.includes(:foo) },
        nrd(:includes!) { |s| s.to_relation.includes!(:foo) },
        nrd(:eager_load) { |s| s.eager_load(:foo) },
        nrd(:eager_load!) { |s| s.to_relation.eager_load!(:foo) },
        nrd(:preload) { |s| s.preload(:foo) },
        nrd(:preload!) { |s| s.to_relation.preload!(:foo) },
        nrd(:references) { |s| s.references(:foo) },
        nrd(:references!) { |s| s.to_relation.references!(:foo) },
        nrd(:select) { |s| s.select("id, name") },
        nrd(:select!) { |s| s.to_relation.select!("id, name") },
        nrd(:group) { |s| s.group(:id) },
        nrd(:group!) { |s| s.to_relation.group!(:id) },
        nrd(:order) { |s| s.order("id") },
        nrd(:order!) { |s| s.to_relation.order!("id") },
        nrd(:reorder) { |s| s.reorder("id") },
        nrd(:reorder!) { |s| s.to_relation.reorder!("id") },
        nrd(:unscope) { |s| s.to_relation.unscope(:order) },
        nrd(:unscope!) { |s| s.to_relation.unscope!(:order) },
        nrd(:joins) { |s| s.joins(:foo) },
        nrd(:joins!) { |s| s.to_relation.joins!(:foo) },
        nrd(:bind) { |s| s.to_relation.bind(:foo => 'bar') },
        nrd(:bind!) { |s| s.to_relation.bind!(:foo => 'bar') },
        nrd(:where) { |s| s.where(:name => 'foo') },
        nrd(:where!) { |s| s.to_relation.where!(:name => 'foo') },
        nrd(:having) { |s| s.to_relation.having("id") },
        nrd(:having!) { |s| s.to_relation.having!("id") },
        nrd(:limit) { |s| s.limit(5) },
        nrd(:limit!) { |s| s.to_relation.limit!(5) },
        nrd(:offset) { |s| s.offset(10) },
        nrd(:offset!) { |s| s.to_relation.offset!(10) },
        nrd(:lock) { |s| s.lock },
        nrd(:lock!) { |s| s.to_relation.lock! },
        nrd(:none) { |s| s.none },
        nrd(:none!) { |s| s.to_relation.none! },
        nrd(:readonly) { |s| s.readonly },
        nrd(:readonly!) { |s| s.to_relation.readonly! },
        nrd(:create_with) { |s| s.create_with(:name => 'foo') },
        nrd(:create_with!) { |s| s.to_relation.create_with!(:name => 'foo') },
        nrd(:from) { |s| s.from("USER") },
        nrd(:from!) { |s| s.to_relation.from!("USER") },
        nrd(:distinct) { |s| s.distinct("id") },
        nrd(:distinct!) { |s| s.to_relation.distinct!("id") },
        nrd(:extending) { |s| s.to_relation.extending(Module.new) },
        nrd(:extending!) { |s| s.to_relation.extending!(Module.new) },
        nrd(:reverse_order) { |s| s.to_relation.reverse_order },
        nrd(:reverse_order!) { |s| s.to_relation.reverse_order! },
        nrd(:arel) { |s| s.to_relation.arel },
        nrd(:build_arel) { |s| s.to_relation.build_arel },

        # ActiveRecord::Relation::Explain
        nrd(:collecting_queries_for_explain) { |s| s.collecting_queries_for_explain { } },
        nrd(:exec_explain) { |s| s.exec_explain([ [ "SELECT * FROM #{::User.table_name}", { } ] ]) },

        # ActiveRecord::Relation::Delegation
        nrd(:table_name) { |s| s.table_name },
        nrd(:quoted_table_name) { |s| s.quoted_table_name },
        nrd(:primary_key) { |s| s.primary_key },
        nrd(:quoted_primary_key) { |s| s.quoted_primary_key },
        nrd(:connection) { |s| s.connection },
        nrd(:columns_hash) { |s| s.columns_hash },
      ].each do |nrd_obj|
        describe "#{nrd_obj.description}" do
          it "should not raise when invoked on the base class" do
            nrd_obj.go!(::User)
          end

          it "should not raise when invoked with one scope" do
            nrd_obj.go!(::User.red)
          end

          it "should not raise when invoked with two scopes" do
            nrd_obj.go!(::User.red.salty)
          end
        end
      end
    end
  end

    # ::User.class_eval do
    #   base_scope_required!

    #   base_scope :red, lambda { where(:favorite_color => 'red') }
    # end

end
