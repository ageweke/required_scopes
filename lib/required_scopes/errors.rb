module RequiredScopes
  module Errors
    class Base < StandardError; end

    class CategoryScopesMustBeDefinedAsProcError < Base; end

    class RequiredScopeCategoriesNotSatisfiedError < Base
      attr_reader :model_class, :current_relation, :triggering_method, :required_categories, :satisfied_categories, :missing_categories

      def initialize(model_class, current_relation, triggering_method, required_categories, satisfied_categories)
        @model_class = model_class
        @current_relation = current_relation
        @triggering_method = triggering_method
        @required_categories = required_categories
        @satisfied_categories = satisfied_categories
        @missing_categories = @required_categories - @satisfied_categories

        super(%{Model #{model_class.name} requires that you apply scope(s) satisfying the following
categories before you use it: #{missing_categories.sort_by(&:to_s).join(", ")}.

Satisfy these categories by including scopes in your query that are tagged with
:category => <category name>, for each of the categories.})
      end
    end
  end
end
