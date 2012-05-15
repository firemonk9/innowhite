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
    :server =>            [8, "cb value (server name) missed"],
  }

  attr_accessor :mod_name, :org_name, :sub, :server_address, :private_key

  def initialize
    load_settings
  end

  def create_room(params = {})
    return err(*@@errors[:user_miss]) if params[:user].blank?
    return err(*@@errors[:server]) if params[:server].blank?
    room_id = get_room_id
    address = join_room_url(params[:server], @org_name, room_id, params[:user], true)
    res = create_room_info(room_id, params[:user], params[:tags], params[:desc], @org_name, address, params[:server])
    res.include?("Missing") ? err(*@@errors[:fetch_fail]) : data({"room_id" => room_id, "address" => address})
  end

  def join_meeting(server, room_id, user)
    return err(*@@errors[:server]) if server.nil?
    return err(*@@errors[:user_miss]) if user.nil?
    return err(*@@errors[:room_miss]) if room_id.nil?
    url = "#{@api_address}exist_session?roomId=#{room_id}"
    Nokogiri::XML(open(url)).text.blank? ? err(-1, "Unknow") : data(join_room_url(server ,@org_name, room_id, user, false))
  end

  def get_sessions(params = {})
    return err(*@@errors[:server]) if params[:server].blank?
    temp = url_generator(params[:parentOrg] || @parent_org, params[:orgName] || @org_name, params[:server])
    checksum = generating_checksum(URI.escape(temp))
    tmp = "#{temp}&user=#{params[:user]}&tags=#{params[:tags]}"
    url = URI.escape("#{@api_address}list_sessions?#{tmp}&checksum=#{checksum}")
    data(JSON::parse(RestClient.get(url, :accept => :json)))

  rescue
    err(*@@errors[:fetch_fail])
  end

  def schedule_meeting(params = {})
    return err(*@@errors[:server]) if params[:server].blank?
    return err(*@@errors[:user_miss]) if params[:user].blank?
    return err(*@@errors[:description_miss]) if params[:description].nil? || params[:description].empty?

    return err(*@@errors[:start_time]) if params[:startTime].blank?
    return err(*@@errors[:end_time]) if params[:endTime].blank?
    return err(*@@errors[:time_zone]) if params[:timeZone].blank?

    room_id = get_room_id
    address = join_room_url(
        params[:server],
        params[:orgName] || @org_name,
        room_id,
        params[:user],
        true)

    data(create_schedule(
        room_id,
        params[:user],
        params[:tags],
        params[:description],
        params[:parentOrg] || @parent_org,
        address,
        params[:startTime],
        params[:endTime],
        params[:timeZone],
        params[:server]) == "true")
  end

  def past_sessions(params = {})
    return err(*@@errors[:server]) if params[:server].blank?
    temp = url_generator(params[:parentOrg] || @parent_org, params[:orgName] || @org_name, params[:server])
    checksum = generating_checksum(URI.escape(temp))

    tmp = "#{temp}&user=#{params[:user]}&tags=#{params[:tags]}"
    url = URI.escape("#{@api_address}past_sessions?#{tmp}&checksum=#{checksum}")
    data(JSON::parse(RestClient.get(url, :accept => :json)))

    rescue
      err(*@@errors[:fetch_fail])
  end

  def get_scheduled_list(params={})
    return err(*@@errors[:server]) if params[:server].blank?
    checksum = main_cheksum(params[:server], params[:parentOrg] || @parent_org, params[:orgName] || @org_name)
    par = url_generator(params[:parentOrg] || @parent_org, params[:orgName] || @org_name, params[:server])
    url = URI.escape("#{@api_address}get_scheduled_sessions?#{par}&checksum=#{checksum}&tags=#{params[:tags]}&user=#{params[:user]}")
    data(JSON::parse(RestClient.get(url, :accept => :json)))
  end

  def cancel_meeting(server, room_id)
    return err(*@@errors[:server]) if server.blank?
    checksum = main_cheksum(server, @parent_org, @org_name)
    par = url_generator(@parent_org, @org_name, server)
    url = URI.escape("#{@api_address}cancel_meeting?roomId=#{room_id}&#{par}&checksum=#{checksum}")
    data(Nokogiri::XML(open(url)).xpath("//success").text == "true")
  end

  def update_schedule(params = {})
    return err(*@@errors[:server]) if params[:server].blank?
    checksum = main_cheksum(params[:server], @parent_org, @org_name)
    params[:startTime] = params[:startTime].to_i  if !params[:startTime].blank? && (params[:startTime].is_a?(DateTime) || params[:startTime].is_a?(Time))
    params[:endTime] = params[:endTime].to_i  if !params[:endTime].blank? && (params[:endTime].is_a?(DateTime) || params[:endTime].is_a?(Time))

    data(Nokogiri::XML(RestClient.put("#{@api_address}update_schedule",
                             {:roomId => params[:room_id], :tags => params[:tags], :description => params[:description],
                              :parentOrg => @parent_org, :orgName => @org_name,
                              :checksum => checksum, :startTime => params[:startTime],
                              :endTime => params[:endTime], :timeZone => params[:timeZone]
                             }
        )).xpath("//success").text == "true")
  end

  def getRecordingURL(room_id)
    v = Nokogiri.parse(RestClient.get("#{@server_address}PlayBackServlet?room_id=#{room_id}"))
    { "webm" => v.css("webMpath").text.gsub(/.webm$/, ""), "mp4" => v.css("mp4path").text}
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
      @server_address = settings["innowhite"]["server_address"]
      @api_address = settings["innowhite"]["api_address"]
      @private_key = settings["innowhite"]["private_key"]
      @parent_org = settings["innowhite"]["organization"]
      @org_name = @parent_org
    end

    def create_schedule(room_id, user, tags, desc, parent_org, address, start_time, end_time, time_zone, server)
      checksum = generating_checksum(URI.escape(url_generator(parent_org, parent_org, server)))
      address = join_room_url(server, @org_name, room_id, user, true)
      RestClient.post("#{@api_address}create_schedule_meeting",
                            {:roomId => room_id, :user => user, :tags => tags, :desc => desc, :startTime => start_time,
                             :endTime => end_time, :timeZone => time_zone,
                             :parentOrg => parent_org, :address => address, :orgName => parent_org,
                             :checksum => checksum
                            }
      )
    end

    def create_room_info(room_id, user, tags, desc, parent_org, address, server)
      checksum = generating_checksum(URI.escape(url_generator(parent_org, parent_org, server)))

      RestClient.post("#{@api_address}create_room_info",
        {:roomId => room_id, :user => user, :tags => tags, :desc => desc,
         :parentOrg => parent_org, :address => address, :orgName => parent_org,
         :checksum => checksum
        }
      )
    end

    def get_room_id
      url = create_room_url
      doc = Nokogiri::XML(open(url))
      status = doc.xpath('//returnStatus').text.gsub("\n", "") rescue ""

      if status.include?('SUCCESS')
        doc.xpath('//roomId').text.gsub("\n", "").to_i
      elsif status.include?('AUTH_FAILED')
        "AUTH_FAILED"
      elsif status.include?('EXPIRED')
        'EXPIRED'
      elsif status.include?('OUT_OF_SERVICE')
        'OUT_OF_SERVICE'
      else
        "Error With the Server #{url}"
      end
    end

  private
    def main_cheksum(server, parent_org, org_name)
      checksum_tmp = url_generator(parent_org, org_name, server)
      generating_checksum(URI.escape(checksum_tmp))
    end

    def generating_checksum(params)
      Digest::SHA1.hexdigest(params + @private_key)
    end

    def generate_checksum(parent_org, org_name, user_name)
      Digest::SHA1.hexdigest(information_url(parent_org, org_name, user_name))
    end

    def url_generator(parent_org, org_name, server)
      "parentOrg=#{parent_org}&orgName=#{org_name}&cb=#{server}"
    end

    def join_room_url(server, org_name, room_id, user, is_teacher)
      action = "#{@server_address}JoinRoom?"
      address = "parentOrg=#{@parent_org}&orgName=#{org_name}&roomId=#{room_id}&user=#{user}&roomLeader=#{is_teacher}&cb=#{server}"
      "#{action}#{address}&checksum=#{generating_checksum(address)}"
    end

    def information_url(parent_org, org_name, user_name)
      "parentOrg=#{parent_org}&orgName=#{org_name}&user=#{user_name}#{@private_key}"
    end

    def create_room_url
      "#{@server_address}CreateRoom?parentOrg=#{@parent_org}&orgName=#{@org_name}&user=#{@mod_name}&checksum=#{generate_checksum(@parent_org, @org_name, @mod_name)}"
    end
end