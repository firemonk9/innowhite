require 'open-uri'
require 'nokogiri'
require 'rest-client'

class Innowhite

  attr_accessor :mod_name, :org_name, :sub, :server_address, :private_key

  def initialize
    load_settings
    #@mod_name = mod_name.gsub(/ /,'')
    #@org_name = org_name.nil? ? @parent_org : org_name
  end

  def load_settings
    settings = YAML.load_file('config/innowhite.yml')# if RAILS_ENV == "development"
    @server_address = settings["innowhite"]["server_address"]
    @api_address = settings["innowhite"]["api_address"]
    @private_key = settings["innowhite"]["private_key"]
    @parent_org = settings["innowhite"]["organization"]
    @org_name = @parent_org
  end

  def create_room(params = {})
    room_id = get_room_id
    address = join_room_url(@org_name, room_id, params[:user], true)
    res = create_room_info(room_id, params[:user], params[:tags], params[:desc], @org_name, address)
    res.include?("Missing") ? "Failed to fetch, maybe you have entered wrong username / organization name .." : {:room_id => room_id, :address => address}
  end

  def join_meeting(room_id, user)
    url = "#{@api_address}exist_session?roomId=#{room_id}"
    doc = Nokogiri::XML(open(url))
    raise "Room is not exist / Expired" if doc.text.blank?
    join_room_url(@org_name, room_id, user, false)
  end

  def get_sessions(params = {})
    temp = url_generator(@parent_org, @org_name)
    checksum = generating_checksum(URI.escape(temp))

    tmp = "#{temp}&user=#{params[:user]}&tags=#{params[:tags]}"
    url = URI.escape("#{@api_address}list_sessions?#{tmp}&checksum=#{checksum}")

    JSON::parse(RestClient.get(url, :accept => :json))

    rescue
      "Error fetching sessions check the organization and private key .."
  end

  def schedule_meeting(params = {})
    params[:startTime] = params[:startTime].to_i  if params[:startTime].is_a?(DateTime) || params[:startTime].is_a?(Time)
    params[:endTime] = params[:endTime].to_i  if params[:endTime].is_a?(DateTime) || params[:endTime].is_a?(Time)

    room_id = get_room_id
    address = join_room_url(
        @org_name,
        room_id,
        params[:user],
        true)
    create_schedule(
        room_id,
        params[:user],
        params[:tags],
        params[:description],
        @parent_org,
        address,
        params[:startTime],
        params[:endTime],
        params[:timeZone]) == "true"
  end

  def past_sessions(params = {})
    temp = url_generator(@parent_org, @org_name)
    checksum = generating_checksum(URI.escape(temp))

    tmp = "#{temp}&user=#{params[:user]}&tags=#{params[:tags]}"
    url = URI.escape("#{@api_address}past_sessions?#{tmp}&checksum=#{checksum}")
    res = JSON::parse(RestClient.get(url, :accept => :json))

    res.map {|o| o.update("video_url" => "http://cplayback1.innowhite.com:8080/tomcat.jsp?vid=#{getRecordingURL(o["id"])}")}

    rescue
      "Error fetching sessions check the organization and private key .."
  end

  def get_scheduled_list(params={})
    checksum = main_cheksum(@parent_org, @org_name)
    par = url_generator(@parent_org, @org_name)

    url = URI.escape("#{@api_address}get_scheduled_sessions?#{par}&checksum=#{checksum}&tags=#{params[:tags]}&user=#{params[:user]}")
    JSON::parse(RestClient.get(url, :accept => :json))
  end

  def cancel_meeting(room_id)
    checksum = main_cheksum(@parent_org, @org_name)
    par = url_generator(@parent_org, @org_name)
    url = URI.escape("#{@api_address}cancel_meeting?roomId=#{room_id}&#{par}&checksum=#{checksum}")
    Nokogiri::XML(open(url)).xpath("//success").text == "true"
  end

  def update_schedule(params = {})
    checksum = main_cheksum(@parent_org, @org_name)
    params[:startTime] = params[:startTime].to_i  if !params[:startTime].blank? && (params[:startTime].is_a?(DateTime) || params[:startTime].is_a?(Time))
    params[:endTime] = params[:endTime].to_i  if !params[:endTime].blank? && (params[:endTime].is_a?(DateTime) || params[:endTime].is_a?(Time))

    Nokogiri::XML(RestClient.put("#{@api_address}update_schedule",
                             {:roomId => params[:room_id], :tags => params[:tags], :description => params[:description],
                              :parentOrg => @parent_org, :orgName => @org_name,
                              :checksum => checksum, :startTime => params[:startTime],
                              :endTime => params[:endTime], :timeZone => params[:timeZone]
                             }
        )).xpath("//success").text == "true"
  end

  def getRecordingURL(room_id)
    Nokogiri.parse(RestClient.get("#{@server_address}PlayBackServlet?room_id=#{room_id}")).css("webMpath").text.gsub(/.webm$/, "")
  end

  protected

    def create_schedule(room_id, user, tags, desc, parent_org, address, start_time, end_time, time_zone)
      checksum = generating_checksum(URI.escape(url_generator(parent_org, parent_org)))
      address = join_room_url(@org_name, room_id, user, true)
      RestClient.post("#{@api_address}create_schedule_meeting",
                            {:roomId => room_id, :user => user, :tags => tags, :desc => desc, :startTime => start_time,
                             :endTime => end_time, :timeZone => time_zone,
                             :parentOrg => parent_org, :address => address, :orgName => parent_org,
                             :checksum => checksum
                            }
      )
    end

    def create_room_info(room_id, user, tags, desc, parent_org, address)
      checksum = generating_checksum(URI.escape(url_generator(parent_org, parent_org)))

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
      action = "#{@server_address}JoinRoom?"
      address = "parentOrg=#{@parent_org}&orgName=#{org_name}&roomId=#{room_id}&user=#{user}&roomLeader=#{is_teacher}"
      "#{action}#{address}&checksum=#{generating_checksum(address)}"
    end

    def information_url(parent_org, org_name, user_name)
      "parentOrg=#{parent_org}&orgName=#{org_name}&user=#{user_name}#{@private_key}"
    end

    def create_room_url
      "#{@server_address}CreateRoom?parentOrg=#{@parent_org}&orgName=#{@org_name}&user=#{@mod_name}&checksum=#{generate_checksum(@parent_org, @org_name, @mod_name)}"
    end
end