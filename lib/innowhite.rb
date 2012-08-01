require 'rest-client'

class Innowhite
  attr_accessor :mod_name, :org_name, :sub, :server_address, :private_key

  def initialize
    load_settings
  end

  def create_room(fullName, meetingName, params = {})
    params.reverse_merge! :duration => 0, :meetingName => meetingName
    data = params.slice(:meetingID, :attendeePW,
                  :moderatorPW, :welcome,
                  :dialNumber, :voiceBridge,
                  :webVoice, :record, :meta,
                  :duration, :meetingName,
                  :description, :tags)
    session_data = params.slice(:description, :tags).update(:fullName => fullName)
    checker([:meetingName], params)
    request(:post, "api_create_room", {:data => data, :session_data => session_data})
  end

  def join_meeting(fullName, meetingID, password)
    params = {:meetingID => meetingID, :password => password, :fullName => fullName }
    checker([:meetingID, :password, :fullName], params)
    request(:post, "api_join_room", :data => params)
  end

  def get_sessions(params = {})
    params.slice!( :fullName, :tags, :organizationName )
    request(:get, "list_sessions", params)
  end

  def schedule_meeting(params = {})
    params.slice!( :fullName, :description, :startTime, :endTime, :timeZone, :tags )
    checker([:fullName, :description, :startTime, :endTime, :timeZone], params)
    request(:post, "create_schedule_meeting", params)
  end

  def past_sessions(params = {})
    params.slice!( :fullName, :tags, :organizationName )
    request(:get, "past_sessions", params)
  end

  def get_scheduled_list(params={})
    params.slice!( :fullName, :tags )
    request(:get, "get_scheduled_sessions", params)
  end

  def cancel_meeting(meetingID, password)
    checker([:meetingID], (hash = {:meetingID => meetingID, :password => password}))
    request(:post, "cancel_meeting", hash)
  end

  def update_schedule(meetingID, params = {})
    return true if params.empty?
    params.update(:meetingID => meetingID)
    params.slice!( :meetingID, :startTime, :endTime, :timeZone, :description, :tags )
    checker([:meetingID], params)
    request(:put, "update_schedule", params)
  end

  def get_recordings(meetingID)
    checker([:meetingID], (hash = {:meetingID => meetingID}))
    request(:get, "api_get_recording_urls", hash)
  end

  protected
    def load_settings
      settings = YAML.load_file('config/innowhite.yml')
      @api_address = settings["api_address"]
      @private_key = settings["private_key"]
      @parent_org = settings["organization"]
    end

  private
    def checker(fields, hash)
      fields.each do |field|
        (raise [field.to_s.humanize, "not set"].join(" ") and return) if hash[field].blank?
      end
    end

    def prepare_url(url, params)
      params.update( :orgName => params[:parentOrg] || @parent_org )
      params.update :checksum => Digest::SHA1.hexdigest(params.to_param) # + @private_key
      [url, "?", params.to_param].join
    end

    def request(method, url, params = {})
      url = prepare_url(@api_address + url, params)
      k = if [:get, "get", :delete, "delete"].include?(method)
        RestClient.send(method, url, :accept => :json)
      else
        RestClient.send(method, url, {}, :accept => :json)
      end
      res = JSON::parse(k).with_indifferent_access
      raise res[:errors] if res.has_key?(:errors)
      res.try(:[], :status) || res
    end
end