module RequiredScopes
  module ActiveRecord
    module VersionCompatibility
      class << self
        delegate :is_association_relation?, :to => :impl

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
      end

      class ActiveRecord3
        def is_association_relation?(relation)
          false
        end
      end
    end
  end
end
