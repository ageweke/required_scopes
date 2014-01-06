module RequiredScopes
  module ActiveRecord
    module VersionCompatibility
      class << self
        delegate :is_association_relation?, :supports_references_method?, :apply_version_specific_fixes!, :to => :impl

        private
        def impl
          @impl ||= if ::ActiveRecord::VERSION::MAJOR == 4
            ActiveRecord4.new
          elsif ::ActiveRecord::VERSION::MAJOR == 3
            ActiveRecord3.new
          else
            raise "RequiredScopes does not support ActiveRecord version #{ActiveRecord::VERSION::STRING} currently."
          end
        end
      end

      class ActiveRecord4
        def is_association_relation?(relation)
          relation.kind_of?(::ActiveRecord::AssociationRelation)
        end

        def supports_references_method?
          true
        end

        def apply_version_specific_fixes!

        end
      end

      class ActiveRecord3
        def is_association_relation?(relation)
          # relation.kind_of?(::ActiveRecord::CollectionAssociation)
          false
        end

        def supports_references_method?
          false
        end

        def apply_version_specific_fixes!
          ::ActiveRecord::Associations::Association.class_eval do
            def target_scope_with_required_scopes_removed
              out = target_scope_without_required_scopes_removed
              out.all_scope_categories_satisfied!
              out
            end

            alias_method_chain :target_scope, :required_scopes_removed
          end
        end
      end
    end
  end
end
