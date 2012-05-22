require 'open-uri'
require 'nokogiri'
require 'rest-client'

class Innowhite

  @@errors = {
    :user_miss =>         [1, "user value missed"],
    :fetch_fail =>        [2, "failed to fetch, maybe you have entered wrong username"],
    :room_miss =>         [3, "room not set"],
    :description_miss =>  [4, "description value not set"],
    :start_time =>        [5, "startTime value missed"],
    :end_time =>          [6, "endTime value missed"],
    :time_zone =>         [7, "timeZone value missed"],
  }

  attr_accessor :mod_name, :org_name, :sub, :server_address, :private_key

  def initialize
    load_settings
  end

  def create_room(params = {})
    return err(*@@errors[:user_miss]) if params[:user].blank?
    room_id = get_room_id(params[:user])
    return room_id[:errors] if room_id.has_key?(:errors)
    res = create_room_info(room_id[:data], params[:user], params[:tags], params[:desc], @org_name)
    $stdout << res.inspect
    res[:status] ? data({"room_id" => room_id[:data], "address" => res[:data]}) : res[:errors]
  end

  def join_meeting(room_id, user)
    return err(*@@errors[:user_miss]) if user.nil?
    return err(*@@errors[:room_miss]) if room_id.nil?
    url = "#{@api_address}exist_session?roomId=#{room_id}"
    res = request("post", url)
    return res[:errors] if res.has_key?(:errors)
    res[:data].blank? ? err(-1, "Unknow") : data(join_room_url(@org_name, room_id, user, false))
  end

  def get_sessions(params = {})
    temp = url_generator(params[:parentOrg] || @parent_org, params[:orgName] || @org_name)
    checksum = generating_checksum(URI.escape(temp))
    tmp = "#{temp}&user=#{params[:user]}&tags=#{params[:tags]}"
    url = URI.escape("#{@api_address}list_sessions?#{tmp}&checksum=#{checksum}")
    request("get", url)

  rescue
    err(*@@errors[:fetch_fail])
  end

  def schedule_meeting(params = {})
    return err(*@@errors[:user_miss]) if !params[:user] || params[:user].blank?
    return err(*@@errors[:description_miss]) if !params[:description] || params[:description].empty?

    return err(*@@errors[:start_time]) if !params[:startTime] || params[:startTime].blank?
    return err(*@@errors[:end_time]) if !params[:endTime] || params[:endTime].blank?
    return err(*@@errors[:time_zone]) if !params[:timeZone] || params[:timeZone].blank?

    room_id = get_room_id(params[:user])
    return room_id[:errors] if room_id.has_key?(:errors)

    create_schedule(
        room_id,
        params[:user],
        params[:tags],
        params[:description],
        params[:parentOrg] || @parent_org,
        params[:startTime],
        params[:endTime],
        params[:timeZone])
  end

  def past_sessions(params = {})
    temp = url_generator(params[:parentOrg] || @parent_org, params[:orgName] || @org_name)
    checksum = generating_checksum(URI.escape(temp))

    tmp = "#{temp}&user=#{params[:user]}&tags=#{params[:tags]}"
    url = URI.escape("#{@api_address}past_sessions?#{tmp}&checksum=#{checksum}")
    request("get", url)

    rescue
      err(*@@errors[:fetch_fail])
  end

  def get_scheduled_list(params={})
    checksum = main_cheksum(params[:parentOrg] || @parent_org, params[:orgName] || @org_name)
    par = url_generator(params[:parentOrg] || @parent_org, params[:orgName] || @org_name)
    url = URI.escape("#{@api_address}get_scheduled_sessions?#{par}&checksum=#{checksum}&tags=#{params[:tags]}&user=#{params[:user]}")
    request("get", url)
  end

  def cancel_meeting(room_id)
    checksum = main_cheksum(@parent_org, @org_name)
    par = url_generator(@parent_org, @org_name)
    url = URI.escape("#{@api_address}cancel_meeting?roomId=#{room_id}&#{par}&checksum=#{checksum}")
    data(request("get", url))[:status]
  end

  def update_schedule(params = {})
    checksum = main_cheksum(@parent_org, @org_name)
    params[:startTime] = params[:startTime].to_i  if !params[:startTime].blank? && (params[:startTime].is_a?(DateTime) || params[:startTime].is_a?(Time))
    params[:endTime] = params[:endTime].to_i  if !params[:endTime].blank? && (params[:endTime].is_a?(DateTime) || params[:endTime].is_a?(Time))

    request("put", "#{@api_address}update_schedule",
                             {:roomId => params[:room_id], :tags => params[:tags], :description => params[:description],
                              :parentOrg => @parent_org, :orgName => @org_name,
                              :checksum => checksum, :startTime => params[:startTime],
                              :endTime => params[:endTime], :timeZone => params[:timeZone]
                             }
        )[:status]
  end

  def getRecordingURL(room_id)
    url = "#{@api_address}api_get_recording_urls?#{{:room_id => room_id}.to_param}}"
    data(request("get", url))
  end

  def self.gen_checksum(params)
    key = params.delete(:key)
    temp = params.to_param
    temp + "&checksum=#{Digest::SHA1.hexdigest(URI.escape(temp) + key)}"
  end

  def get_room_id(user)
    url = "#{@api_address}api_create_room?#{{:parentOrg => @parent_org, :orgName => @org_name, :user => user, :key => @private_key}.to_param}"
    request("get", url)
  end

  protected
    def err(code, message)
      {"errors" => {"message" => message, "code" => code}}.with_indifferent_access
    end

    def data(values)
      {"data" => values}.with_indifferent_access
    end

    def load_settings
      settings = YAML.load_file('config/innowhite.yml')# if RAILS_ENV == "development"
      @api_address = settings["innowhite"]["api_address"]
      @private_key = settings["innowhite"]["private_key"]
      @parent_org = settings["innowhite"]["organization"]
      @org_name = @parent_org
    end

    def create_schedule(room_id, user, tags, desc, parent_org, start_time, end_time, time_zone)
      checksum = generating_checksum(URI.escape(url_generator(parent_org, parent_org)))
      request("post", "#{@api_address}create_schedule_meeting",
                            {:roomId => room_id, :user => user, :tags => tags, :desc => desc, :startTime => start_time,
                             :endTime => end_time, :timeZone => time_zone,
                             :parentOrg => parent_org, :orgName => parent_org,
                             :checksum => checksum,  :roomLeader => true,
                             :key => @private_key
                            }
      )[:status]
    end

    def create_room_info(room_id, user, tags, desc, parent_org)
      checksum = generating_checksum(URI.escape(url_generator(parent_org, parent_org)))

      request("post", "#{@api_address}create_room_info",
        {:roomId => room_id, :user => user, :tags => tags, :desc => desc,
         :parentOrg => parent_org, :orgName => parent_org,
         :checksum => checksum, :key => @private_key
        }
      )
    end

  private

    def request(method, url, *params)
      url = url + "?" + params.to_param unless params.blank?
      k = if method == "get" || method == "delete"
        RestClient.send(method, url, :accept => :json)
      else
        RestClient.send(method, url, {}, :accept => :json)
      end
      $stdout << k.inspect
      JSON::parse(k).with_indifferent_access
    end

    def main_cheksum(parent_org, org_name)
      checksum_tmp = url_generator(parent_org, org_name)
      generating_checksum(URI.escape(checksum_tmp))
    end

    def generating_checksum(params)
      Digest::SHA1.hexdigest(params + @private_key)
    end

    def generate_checksum(parent_org, org_name, user_name)
      Digest::SHA1.hexdigest(information_url(parent_org, org_name, user_name))
    end

    def url_generator(parent_org, org_name)
      "parentOrg=#{parent_org}&orgName=#{org_name}"
    end

    def join_room_url(org_name, room_id, user, is_teacher)
      url = "#{@api_address}api_join_room?#{{:parentOrg => @parent_org, :orgName => org_name, :user => user, :roomId => room_id, :roomLeader => is_teacher, :key => @private_key}.to_param}"
      request("post", url)[:data]
    end

    def information_url(parent_org, org_name, user_name)
      "parentOrg=#{parent_org}&orgName=#{org_name}&user=#{user_name}#{@private_key}"
    end
end