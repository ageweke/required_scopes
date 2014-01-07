module RequiredScopes
  module ActiveRecord
    module VersionCompatibility
      class << self
        delegate :is_association_relation?, :supports_references_method?, :apply_version_specific_fixes!,
          :supports_find_by?, :relation_method_for_ignoring_scopes, :supports_load?, :supports_take?,
          :supports_ids?, :supports_spawn?, :supports_bang_methods?, :supports_references?,
          :supports_unscope?, :supports_none?, :supports_distinct?, :to => :impl

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

        def supports_find_by?
          true
        end

        def supports_load?
          true
        end

        def supports_take?
          true
        end

        def supports_ids?
          true
        end

        def supports_spawn?
          true
        end

        def supports_bang_methods?
          true
        end

        def supports_references?
          true
        end

        def supports_unscope?
          true
        end

        def supports_none?
          true
        end

        def supports_distinct?
          true
        end

        def relation_method_for_ignoring_scopes
          :all
        end
      end

      class ActiveRecord3
        def is_association_relation?(relation)
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

          ::ActiveRecord::Base.class_eval do
            def destroy_with_required_scopes_removed
              self.class.all_scope_categories_satisfied do
                destroy_without_required_scopes_removed
              end
            end

            alias_method_chain :destroy, :required_scopes_removed
          end
        end

        def supports_find_by?
          false
        end

        def supports_load?
          false
        end

        def supports_take?
          false
        end

        def supports_ids?
          false
        end

        def supports_spawn?
          false
        end

        def supports_bang_methods?
          false
        end

        def supports_references?
          false
        end

        def supports_unscope?
          false
        end

        def supports_none?
          false
        end

        def supports_distinct?
          false
        end

        def relation_method_for_ignoring_scopes
          :relation
        end
      end
    end
  end
end
