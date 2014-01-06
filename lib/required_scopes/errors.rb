module RequiredScopes
  module Errors
    # The parent of all errors raised by RequiredScopes.
    class Base < StandardError; end

    # Raised if you try to execute an operation on a model or relation without having satisfied one or more
    # scopes.
    class RequiredScopeCategoriesNotSatisfiedError < Base
      attr_reader :model_class, :current_relation, :triggering_method, :required_categories, :satisfied_categories, :missing_categories

      def initialize(model_class, current_relation, triggering_method, required_categories, satisfied_categories)
        @model_class = model_class
        @current_relation = current_relation
        @triggering_method = triggering_method
        @required_categories = required_categories
        @satisfied_categories = satisfied_categories
        @missing_categories = @required_categories - @satisfied_categories

        super(build_message)
      end

      private
      def build_message
        %{Model #{model_class.name} requires that you apply scope(s) satisfying the following
categories before you use it: #{missing_categories.sort_by(&:to_s).join(", ")}.

Satisfy these categories by including scopes in your query that are tagged with
:satisfies => <category name>, for each of the categories.}
      end
    end

    # Raised if you try to execute an operation on a model or relation without having satisfied the base scope.
    # (We use this instead of RequiredScopeCategoriesNotSatisfiedError, above, simply to make the error message
    # simpler and more comprehensible to users who only are using the "base scope" syntactic sugar.)
    class BaseScopeNotSatisfiedError < RequiredScopeCategoriesNotSatisfiedError
      def initialize(model_class, current_relation, triggering_method)
        super(model_class, current_relation, triggering_method, [ :base ], [ ])
      end

      private
      def build_message
        %{Model #{model_class.name} requires specification of a base scope before using it in a query
or other such operation. (Base scopes are those declared with #base_scope rather than just #scope,
or class methods that include #satisfying_base_scope.)}
      end
    end
  end
end
