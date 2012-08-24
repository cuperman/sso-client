require 'excon'
require 'active_support/json'
require 'active_support/core_ext/object/to_query'
require 'active_support/core_ext/hash/keys'

class Bsm::Sso::Client::AbstractResource < Hash

  class << self

    # @param [String] url
    def site=(url)
      @site = Excon.new url,
        :idempotent => true,
        :expects    => [200, 422],
        :headers    => { 'Accept' => Mime::JSON.to_s, 'Content-Type' => Mime::JSON.to_s }
    end

    # @return [Excon::Connection] site connection
    def site
      @site || (superclass.respond_to?(:site) && superclass.site) || raise("No site specified for #{name}. Please specify #{name}.site = 'http://your.sso.host'")
    end

    # @return [Hash] default headers
    def headers
      { 'Authorization' => Bsm::Sso::Client.verifier.generate(30.seconds.from_now) }
    end

    # @param [String] path
    # @param [Hash] params, request params - see Excon::Connection#request
    # @return [Bsm::Sso::Client::AbstractResource] fetches object from remote
    def get(path, params = {})
      params[:query] ||= params.delete(:params)
      collection = params.delete(:collection)
      params = params.merge(:path => path)
      params[:headers] = (params[:headers] || {}).merge(headers)
      response = site.get(params)
      return (collection ? [] : nil) unless response.status == 200

      result = ActiveSupport::JSON.decode(response.body) 
      if collection
        result.map do |record|
          instance = new(record)
          instance if instance.id
        end.compact
      else
        instance = new result
        instance if instance.id
      end
    rescue MultiJson::DecodeError
      collection ? [] : nil
    end

  end

  # Constuctor
  # @param [Hash,NilClass] attributes the attributes to assign
  def initialize(attributes = nil)
    super()
    update(attributes.stringify_keys) if attributes.is_a?(Hash)
  end

  # @return [Integer] ID, the primary key
  def id
    self["id"]
  end

  # @return [Boolean] true, if method exists?
  def respond_to?(method, *)
    super || key?(method.to_s.sub(/[=?]$/, ''))
  end

  # @return [Hash] attributes hash
  def attributes
    dup
  end

  protected

    def method_missing(method, *arguments)
      method, punctation = method.to_s.sub(/([=?])$/, ''), $1

      case punctation
      when "="
        store(method, arguments.first)
      when "?"
        self[method]
      else
        key?(method) ? fetch(method) : super
      end
    end

end