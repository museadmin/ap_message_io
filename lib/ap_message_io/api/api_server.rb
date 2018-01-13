require "rack"

# Taken from https://robots.thoughtbot.com/lets-build-a-sinatra
module ApiServer

  class Base
    def initialize
      @routes = {}
    end

    attr_reader :routes, :request

    # Delegated route addition handlers
    def get(path, &handler)
      route("GET", path, &handler)
    end

    def post(path, &handler)
      route("POST", path, &handler)
    end

    def put(path, &handler)
      route("PUT", path, &handler)
    end

    def patch(path, &handler)
      route("PATCH", path, &handler)
    end

    def delete(path, &handler)
      route("DELETE", path, &handler)
    end

    def head(path, &handler)
      route("HEAD", path, &handler)
    end

    # Called for every request. Finds the appropriate handler
    def call(env)
      @request = Rack::Request.new(env)
      verb = @request.request_method
      requested_path = @request.path_info
      handler = @routes.fetch(verb, {}).fetch(requested_path, nil)

      if handler
        result = instance_eval(&handler)
        if result.class == String
          [200, {}, [result]]
        else
          result
        end
      else
        [404, {}, ["Oops! No route for #{verb} #{requested_path}"]]
      end
    end

    private

    #Add a route to the routes array
    def route(verb, path, &handler)
      @routes[verb] ||= {}
      @routes[verb][path] = handler
    end

    # Access the parameter passed in a request
    def params
      @request.params
    end
  end

  # Create an instance of the base class
  Application = Base.new
  # Now delegate our route methods to it
  module Delegator
    def self.delegate(*methods, to:)
      Array(methods).each do |method_name|
        define_method(method_name) do |*args, &block|
          to.send(method_name, *args, &block)
        end
        # private method_name
      end
    end
    # Call delegate and pass in array of methods to delegate to our Application
    delegate :get, :patch, :put, :post, :delete, :head, to: Application
  end
end
include ApiServer::Delegator
