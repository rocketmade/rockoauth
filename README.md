[![Gem Version](https://badge.fury.io/rb/rockoauth.png)](https://rubygems.org/gems/rockoauth)
[![Build Status](https://secure.travis-ci.org/rocketmade/rockoauth.png?branch=master)](http://travis-ci.org/rocketmade/rockoauth)
[![Code Climate](https://codeclimate.com/github/rocketmade/rockoauth.png)](https://codeclimate.com/github/rocketmade/rockoauth)

# RockOAuth Oauth 2 Provider

This gem provides a toolkit for adding OAuth2 provider capabilities to a Ruby
web app. It handles most of the protocol for you: it is designed to provide
a sufficient level of abstraction that it can implement updates to the protocol
without affecting your application code at all. All you have to deal with is
authenticating your users and letting them grant access to client apps.

It is also designed to be usable within any web frontend, at least those of
Rails and Sinatra. Its API uses Rack request-environment hashes rather than
framework-specific request objects, though you can pass those in and their
`request.env` property will be used internally.

It stores the clients and authorizations using ActiveRecord.

It is forked from [songkick-oauth2-provider](https://github.com/songkick/oauth2-provider).
With much appreciation for their excellent work.

## Installation

```bash
gem install rockoauth
```

## Supported versions

This gem is tested on:

- Ruby
  - 1.9.3
  - 2.0.0
  - 2.1.0
- Active Record
  - 4.0
  - 4.1

### A note on versioning

This library is based on [draft-10](http://tools.ietf.org/html/draft-ietf-oauth-v2-10),
which was current when we began writing it. Having observed the development of
the OAuth 2.0 spec over time, we have decided not to upgrade to later drafts
until the spec is finalized. There is not enough meaningful change going on to
merit migrating to every draft version - it would simply create a lot of
turbulence and make it hard to reason about exactly what semantics the library
supports.

During draft state, the gem version will indicate which draft it implements
using the minor version, for example `0.10.2` means the second bug-fix
release for draft 10.

## Terminology

- __Client__: A third-party software system that integrates with the provider.
  Twitter and Facebook call this an "app".
- __Client Owner__: The entity which owns a __client__, i.e. the
  individual or company responsible for the client application.
- __Resource Owner__: This will almost certainly be a User. It's the entity
  which has the data that the __client__ is asking permission to see.
- __Authorization__: When a __resource owner__ grants access to a
  __client__ (i.e., a user grants access to a company's app), an
  authorization is created. This can typically be revoked by the user at any
  time (which is the strength and flexibility of the OAuth architecture).
- __Access Token__: An opaque string representing an __authorization__.
  A __client__ is given an access token when a __resource owner__ grants
  it access to resources. The access token must be included in all requests for
  protected resources.

## Usage

A basic example is in [`example/application.rb`](example/application.rb). To implement OAuth, you
need to provide four things:

- Some UI to register client applications
- The OAuth request endpoint
- A flow for logged-in users to grant access to clients
- Resources protected by access tokens

###  Declare your app's name

Declare your app's name somewhere (for example in Rails, in `application.rb`
or an initializer):

```ruby
require 'rockoauth/provider'
RockOAuth::Provider.realm = 'My OAuth app'
```

### HTTPS

Your application should ensure that any endpoint that receives or returns OAuth
data is only accessible over a secure transport such as the `https:`
protocol. `RockOAuth::Provider` can enforce this to make it easier
to keep your users' data secure.

You can set `RockOAuth::Provider.enforce_ssl = true` in the same
place that you declared your app name above. This will result in the following
behavior:

- The `RockOAuth::Provider.parse` method will produce error
  responses and will not process the incoming request unless the request was
  made using the `https:` protocol.
- An access token constructed using `RockOAuth::Provider.access_token`
  will return `false` for `#valid?` unless the request was made
  using the `https:` protocol.
- Any access token received over an insecure connection is immediately destroyed
  to prevent eavesdroppers getting access to the user's resources. A client
  making an insecure request will have to send the user through the
  authorization process again to get a new token.

### Schema

Add the `RockOAuth::Provider` tables to your app's schema. This is
done using `RockOAuth::Model::Schema.migrate`, which will run all
the gem's migrations that have not yet been applied to your database.

```ruby
RockOAuth::Model::Schema.migrate
I, [2012-10-31T14:52:33.801428 #7002]  INFO -- : Migrating to RockoauthSchemaOriginalSchema (20120828112156)
==  Rockoauth2SchemaOriginalSchema: migrating =============================
-- create_table(:oauth2_clients)
   -> 0.0029s
-- add_index(:oauth2_clients, [:client_id])
   -> 0.0009s
...
```

To rollback migrations, use `RockOAuth::Model::Schema.rollback`.

### Model Mixins

There are two mixins you need to put in your code,
`RockOAuth::Model::ClientOwner` for whichever model will own the
"apps", and `RockOAuth::Model::ResourceOwner` for whichever model
is the innocent, unassuming entity who will selectively share their data. It's
possible that this is the same model, such as `User`:

```ruby
class User < ActiveRecord::Base
  include RockOAuth::Model::ResourceOwner
  include RockOAuth::Model::ClientOwner
  has_many :interesting_pieces_of_data
end
```

Or they might go into two different models:

```ruby
class User < ActiveRecord::Base
  include RockOAuth::Model::ResourceOwner
  has_many :interesting_pieces_of_data
end

class Company < ActiveRecord::Base
  include RockOAuth::Model::ClientOwner
  belongs_to :user
end
```

To see the methods and associations that these two mixins add to your models,
take a look at ['lib/rockoauth/model/client_owner.rb'](lib/rockoauth/model/client_owner.rb) and
['lib/rockoauth/model/resource_owner.rb'](lib/rockoauth/model/resource_owner.rb).

### Registering client applications

Clients are modeled by the `RockOAuth::Model::Client` class, which
is an ActiveRecord model. You just need to implement a UI for creating them, for
example in a Sinatra app:

```ruby
get '/oauth/apps/new' do
  @client = RockOAuth::Model::Client.new
  erb :new_client
end

post '/oauth/apps' do
  @client = RockOAuth::Model::Client.new(params)
  @client.save ? erb(:show_client) : erb(:new_client)
end
```

Client applications must have a `name` and a `redirect_uri`:
provide fields for editing these but do not allow the other fields to be edited,
since they are the client's access credentials. When you've created the client,
you should show its details to the user registering the client: its
`name`, `redirect_uri`, `client_id` and
`client_secret` (the last two are generated for you).
`client_secret` is not stored in plain text so you can only read it when
you initially create the client object.

### OAuth request endpoint

This is a path that your application exposes in order for clients to communicate
with your application. It is also the page that the client will send users to
so they can authenticate and grant access. Many requests to this endpoint will
be protocol-level requests that do not involve the user, and
`RockOAuth::Provider` gives you a generic way to handle all that.

You should use this to get the right response, status code and headers to send
to the client. In the event that `RockOAuth::Provider` does not
provide a response, you should render a page that lets the user begin to
authenticate and grant access. This can happen in two cases:

- The client makes a valid Authorization request. In this case you should
  display a login flow to the user so they can authenticate and grant access to
  the client.
- The client makes an invalid Authorization request and the provider cannot
  redirect back to the client. In this case you should display an error page
  to the user, possibly including the value of `@oauth2.error_description`.

This endpoint must be accessible via GET and POST. In this example we will
expose the OAuth service through the path `/oauth/authorize`. We check if
there is a logged-in resource owner and give this to `OAuth::Provider`,
since we may be able to immediately redirect if the user has already authorized
the client:

```ruby
[:get, :post].each do |method|
  __send__ method, '/oauth/authorize' do
    @owner  = User.find_by_id(session[:user_id])
    @oauth2 = RockOAuth::Provider.parse(@owner, env)

    if @oauth2.redirect?
      redirect @oauth2.redirect_uri, @oauth2.response_status
    end

    headers @oauth2.response_headers
    status  @oauth2.response_status

    if body = @oauth2.response_body
      body
    elsif @oauth2.valid?
      erb :login
    else
      erb :error
    end
  end
end
```

There is a set of parameters that you will need to hold on to for when your app
needs to redirect back to the client. You could store them in the session, or
pass them through forms as the user completes the flow. For example to embed
them in the login form, do this:

```erb
<% @oauth2.params.each do |key, value| %>
  <input type="hidden" name="<%= key %>" value="<%= value %>">
<% end %>
```

You may also want to use scopes to provide granular access to your domain using
_scopes_. The `@oauth2` object exposes the scopes the client has
asked for so you can display them to the user:

```erb
<p>The application <%= @oauth2.client.name %> wants the following permissions:</p>

<ul>
  <% @oauth2.scopes.each do |scope| %>
    <li><%= PERMISSION_UI_STRINGS[scope] %></li>
  <% end %>
</ul>
```

You can also use the method `@oauth2.unauthorized_scopes` to get the list
of scopes the user has not already granted to the client, in the case where the
client already has some authorization. If no prior authorization exists between
the user and the client, `@oauth2.unauthorized_scopes` just returns all
the scopes the client has asked for.

### Granting access to clients

Once the user has authenticated you should show them a page to let them grant
or deny access to the client application. This is straightforward; let's say the
user checks a box before posting a form to indicate their intent:

```ruby
post '/oauth/allow' do
  @user = User.find_by_id(session[:user_id])
  @auth = RockOAuth::Provider::Authorization.new(@user, params)

  if params['allow'] == '1'
    @auth.grant_access!
  else
    @auth.deny_access!
  end
  redirect @auth.redirect_uri, @auth.response_status
end
```

After granting or denying access, we just redirect back to the client using a
URI that `RockOAuth::Provider` will provide for you.

### Using password credentials

If you like, OAuth lets you use a user's login credentials to authenticate with
a provider. In this case the client application must request these credentials
directly from the user and then post them to the exchange endpoint. On the
provider side you can handle this using the `handle_passwords` and
`grant_access!` API methods, for example:

```ruby
RockOAuth::Provider.handle_passwords do |client, username, password, scopes|
  user = User.find_by_username(username)
  if user.authenticate?(password)
    user.grant_access!(client, :scopes => scopes, :duration => 1.day)
  else
    nil
  end
end
```

The block receives the `Client` making the request, the username,
password and a `Set` of the requested scopes. It must return
`user.grant_access!(client)` if you want to allow access, otherwise it
should return `nil`.

### Using assertions

Assertions provide a way to access your OAuth services using user credentials
from another service. When using assertions, the user will not authenticate on
your web site; the OAuth client will authenticate the user using some other
framework and obtain a token, then exchange this token for an access token on
your domain.

For example, a client application may let a user authenticate using Facebook,
so the application obtains a Facebook access token from the user. The client
would then pass this token to your OAuth endpoint and exchange it for an access
token from your site. You will typically create an account in your database to
represent this, then have that new account grant access to the client.

To use assertions, you must tell `RockOAuth::Provider` how to
handle assertions based on their type. An assertion type must be a valid URI.
For the Facebook example we'd do the following. The block yields the
`Client` object making the exchange request, the value of the assertion,
which in this example will be a Facebook access token, and a `Set` of
requested scopes.

```ruby
RockOAuth::Provider.handle_assertions 'https://graph.facebook.com/me' do |client, assertion, scopes|
  facebook = URI.parse('https://graph.facebook.com/me?access_token=' + assertion)
  response = Net::HTTP.get_response(facebook)

  user_data = JSON.parse(response.body)
  account   = User.from_facebook_data(user_data)

  account.grant_access!(client, :scopes => scopes)
end
```

This code should run when your app boots, not during a request handler - think
of it as configuration for `RockOAuth::Provider`. The framework
will invoke it when a client attempts to use assertions with your OAuth endpoint.

The final call in your handler should be to `grant_access!`; this returns
an `Authorization` object that the framework then uses to complete the
response to the client. If you want to deny the request for whatever reason, the
block must return `nil`. If a client tries to use an assertion type you
have no handler for, the client will get an error response.

### Protecting resources with access tokens

To protect the user's resources you need to check for access tokens. This is
simple, for example a call to get a user's notes:

```ruby
get '/user/:username/notes' do
  user  = User.find_by_username(params[:username])
  token = RockOAuth::Provider.access_token(user, ['read_notes'], env)

  headers token.response_headers
  status  token.response_status

  if token.valid?
    JSON.unparse('notes' => user.notes)
  else
    JSON.unparse('error' => 'No notes for you!')
  end
end
```

`RockOAuth::Provider.access_token()` takes a
`ResourceOwner`, a list of scopes required to access the resource, and a
request environment object. If the token was not granted for the required scopes,
has expired or is simply invalid, headers and a status code are set to indicate
this to the client. `token.valid?` is the call you should use to
determine whether to serve the request or not.

It is also common to provide a dynamic resource for getting some basic data
about a user by supplying their access token. This can be done by passing
`:implicit` as the resource owner:

```ruby
get '/me' do
  token = RockOAuth::Provider.access_token(:implicit, [], env)
  if token.valid?
    JSON.unparse('username' => token.owner.username)
  else
    JSON.unparse('error' => 'Keep out!')
  end
end
```

`token.owner` returns the `ResourceOwner` that issued the token.
A token represents the fact that a single owner gave a single client a set of
permissions.

## License

Copyright (c) 2014 Rocketmade.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

Copyright (c) 2010-2012 Songkick.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
