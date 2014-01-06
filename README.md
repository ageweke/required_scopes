# RequiredScopes

RequiredScopes keeps developers from being able to accidentally forget about critical scopes on database tables. For
example:

* If you provide software-as-a-service to many clients, forgetting to include the client ID in your query may leak
  data from one client to another &mdash; potentially a truly disastrous thing to happen.
* If you store time-series data in a table that gets very large, querying without including a time range can cause
  huge scalability problems as you accidentally scan the entire table.
* If you associate permissions with various records in a table, then forgetting to constrain on the permissions in a
  query results in them being completely ineffective.
* If you soft-delete records (via a `deleted_at` or `deleted` flag), forgetting to either explicitly include or exclude
  deleted records can result in "deleted" data reappearing, which can be very bad.

...and the list goes on.

RequiredScopes works by letting you create one or more _required scope categories_, each named via a symbol
(_e.g._, `:client_id`, `:time_range`, `:permissions`, or `:deleted`). You can then declare scopes (or class methods)
as _satisfying_ one or more categories. When time comes to query the database, at least one scope satisfying each
category must have been used, or else an exception will be raised.

For example:

    class StatusUpdate < ActiveRecord::Base
      must_scope_by :client_id, :recency

      scope :last_week, lambda { where("created_at >= ?", 1.week.ago) }, :satisfies => :recency
      scope :last_month, lambda { where("created_at >= ?", 1.month.ago) }, :satisfies => :recency

      class << self
        def for_client(client_id)
          where(:client_id => client_id).satisfying_categories(:client_id)
        end
      end
    end

    StatusUpdate.last(100)                 # => RequiredScopes::Errors::RequiredScopeCategoriesNotSatisfiedError
    StatusUpdate.for_client(982).last_week # => [ <StatusUpdate id:321890414>, <StatusUpdate id:321890583>, ... ]

There's much more, too. For example, it's trivial to skip these checks if you want &mdash; the idea is to keep
developers from simply _forgetting_ about scoping, not to make their lives more difficult. See below, under **Usage**,
for more information.

#### As an alternative to `default_scope`

RequiredScopes was actually born as an alternative to `default_scope`. Rails' `default_scope` is a great idea, but, in
actual usage, we've seen it cause a surprisingly large number of bugs. (It works exactly the way it claims it does,
but it turns out this isn't actually a great way for it to work.)

What goes wrong? It turns out that there's almost never a single scope that you truly want applied 100%, or even 99%,
of the time. Instead, it's more like 85%; but, because it's the default, developers almost always completely forget
about it, and bugs result.

For example, take the classic case of a `deleted_at` column on a User model, and
`default_scope lambda { where('deleted_at IS NULL')} }`. This works great for most "normal" functions of the
application. But, then, the edge cases start creeping in:

* In your admin controllers, where you _want_ to be able to see deleted users, you keep forgetting to apply `#unscoped`
  &mdash; and lots of errors on `nil` result.
* When a new user signs up and chooses a username, you forget to unscope when checking if an existing user has that
  username, resulting in database unique-index failures on `users.username` when creating a new user (and HTTP 500
  pages returned to the end user).
* Your "reset password" page almost certainly wants to find a user account even if it's deleted, and (at minimum)
  display a message telling the user they have a deleted account. You don't want to act like the user simply doesn't
  exist.

The truth is, there _isn't_ a single default scope that can ever be safely applied across-the-board. Developers have to
think about it, every single time. This isn't hard; it takes an extra second or two, and prevents hours of debugging
time (and lots of user frustration at bugs that would've resulted). But base Rails only lets you decide to either apply
a single `default_scope` across the board (where you run into the above problems) or not (where you run into even worse
ones, as developers completely forget about your `deleted_at` column, or whatever).

Hence, RequiredScopes. It prevents you from forgetting about critical scopes, yet doesn't try to shoehorn a single
`default_scope` everywhere.

## Installation

Add this line to your application's Gemfile:

    gem 'required_scopes'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install required_scopes

## Usage

#### `base_scope_required!`, or, the simple version

An example:

    class User < ActiveRecord::Base
      base_scope_required!

      # #base_scope is just like #scope, except that it says "this scope satisfies base_scope_required!"
      base_scope :deleted, lambda { where("deleted_at IS NOT NULL") }
      base_scope :not_deleted, lambda { where("deleted_at IS NULL") }

      # #scope does not satisfy the requirement
      scope :young, lambda { where("age <= 20") }

      class << self
        def deleted_recently
          # The call to #satisfying_categories(:base) says "the scope I'm returning satisfies #base_scope_required!"
          where("deleted_at >= ?", 1.week.ago).satisfying_categories(:base)
        end
      end
    end

This sets up the following behavior:

    # Forgetting the scope gives you an error
    User.first                   # => RequiredScopes::Errors::BaseScopeNotSatisfiedError
    User.young.first             # => RequiredScopes::Errors::BaseScopeNotSatisfiedError

    # Any of the declared scopes work just fine
    User.deleted.first           # => SELECT * FROM users WHERE deleted_at IS NOT NULL LIMIT 1
    User.not_deleted.first       # => SELECT * FROM users WHERE deleted_at IS NULL LIMIT 1
    User.deleted_recently.first  # => SELECT * FROM users WHERE deleted_at >= '2013-12-30 05:23:01.367705' LIMIT 1

    # You can chain them like normal, and use them anywhere
    User.where(:name => 'some user').not_deleted.first
         # => SELECT * FROM users WHERE deleted_at IS NULL AND name = 'some user' LIMIT 1

    # Pass them around, build on them...they work just like any other scope
    s = User.where(:name => 'some user')
    s.not_deleted.first
         # => SELECT * FROM users WHERE deleted_at IS NULL AND name = 'some user' LIMIT 1
    s.deleted.first
         # => SELECT * FROM users WHERE deleted_at IS NOT NULL AND name = 'some user' LIMIT 1
    s.deleted_recently.where("age > 20").first
         # => SELECT * FROM users WHERE deleted_at >= '2013-12-30 05:23:01.367705' AND name = 'some user' AND age > 20 LIMIT 1

    # The special scope "ignoring_base" is generated for you; it satisfies the requirement without constraining in any way
    User.ignoring_base.first # => SELECT * FROM users LIMIT 1
    # #unscoped automatically satisfies all requirements, without constraining in any way
    User.unscoped.first      # => SELECT * FROM users LIMIT 1

#### `must_scope_by`, or, the general case

`base_scope_required!` and `base_scope` are actually just syntactic sugar on top of a more general system that lets
you declare one or more _scope categories_ (each of which is just a symbol) and various scopes and class methods that
_satisfy_ those categories. For example:

    class User < ActiveRecord::Base
      must_scope_by :deleted, :client

      scope :not_deleted, lambda { where("deleted_at IS NULL") }, :satisfies => :deleted
      scope :deleted, lambda { where("deleted_at IS NOT NULL") }, :satisfies => :deleted

      scope :admin_active, lambda { where("deleted_at IS NULL AND client_id = 0") }, :satisfies => [ :deleted, :client ]

      class << self
        def for_client(c)
          where(:client_id => c.id).satisfying_category(:client)
        end

        def active_for_client(c)
          where(:client_id => c.id, :deleted_at => nil).satisfying_categories(:client, :deleted)
        end
      end
    end

This sets up two categories of scopes that _both_ must be satisfied before you can query the database, `:deleted` and
`:client`. The scopes `not_deleted` and `deleted` satisfy the `:deleted` category; the scope `admin_active` satisfies
both. The class method `for_client` satisfies the `:client` category; the class method `active_for_client` satisfies
both categories.

For each required category, a special `ignoring` scope is automatically defined &mdash; `ignoring_deleted`
and `ignoring_client` in the above example. This tells RequiredScopes that you're explicitly deciding _not_ to apply
any scopes for the given category. So, while `User.not_deleted.first` will raise an exception complaining that you
haven't satisfied the `:client` category, `User.not_deleted.ignoring_client.first` will run just fine, and will not
constrain on client in any way.

The built-in ActiveRecord `#unscoped` method always is considered to satisfy all scopes, in either block form or
inline form: `User.unscoped.first` and `User.unscoped { User.first }` will both return the first user, without regard
to client or `deleted_at`.

#### RequiredScopes and Inheritance

If you use inheritance among your model classes, child classes will require any scope categories that their parents
have declared to require; if you add a separate `must_scope_by` call in the child class, then it will additionally
require those categories, too.

If you do _not_ want a child class to require all the categories of its parent, call
`ignore_parent_scope_requirement :client, :deleted` (or whatever categories you want to skip the requirement for) in
the child class. This removes the requirement from the child class.

#### How Smart Is It?

It's important to note that RequiredScopes does not, in any way, _actually look at your WHERE clauses_. That is, the
only thing it's doing is matching the categories you've said are required with scopes that satisfy those categories;
it does not know or care what those scopes actually _do_.

If you say a scope satisfies a category, then RequiredScopes will be happy with it, even if it actually just does
`ORDER BY id ASC` (or does nothing at all!). If no scope is applied that satisfies a category, you'll get an error,
even if you've constrained every column in seven different ways.

This hopefully makes the entire system much easier to understand, but it's worth noting.

#### Along With `default_scope`

Note that RequiredScopes does not affect the behavior of `default_scope` in any way; if you declare a `default_scope`,
it will still be used, as normal. `default_scope`s cannot satisfy any categories, however. (But this wouldn't make any
sense, anyway: if your default scope satisfies a category, then it's really not required any more, is it?)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
