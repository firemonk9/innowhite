require 'spec_helper'



describe Innowhite do
  let(:user) { "jb" }
  let(:user2) { "jeyboy" }

  let(:room_with_video) { 875459280 }
  let(:room_without_video) { 601981929 }

  before do
    #@config = YAML::load(File.open(File.join(File.dirname(__FILE__), "config.yml")))
    @i = Innowhite.new
    @v1 = @i.create_room(:user => user, :tags => "ret, yoyo, huh")
      @v1_1 = @i.schedule_meeting({:user => user, :description => "123", :startTime => (DateTime.now - 1.year).to_i, :endTime => (DateTime.now - 1.week).to_i, :timeZone => 2})
      @v1_2 = @i.schedule_meeting({:user => user, :description => "321", :startTime => (DateTime.now - 1.year).to_i, :endTime => (DateTime.now - 1.week).to_i, :timeZone => 1})
    @v2 = @i.create_room(:user => user, :tags => "toto, yoyo, hru")
    @v3 = @i.create_room(:user => user, :tags => "hru xxx")
    @v4 = @i.create_room(:user => user2, :tags => "1,2,3")
  end

  describe "create_room" do
    it "correct" do
      v = @i.create_room(:server => "innowhite",:user => user)
      !v.has_key?("errors")
    end

    describe "incorrect" do
      it "user not set" do
        v = @i.create_room(:server => "innowhite")
        v.has_key?("errors") && v["errors"]["code"] == 1
      end

      #it "wrong user set" do
      #  v = @i.create_room(:server => "innowhite")
      #  v.has_key?("errors") && v["errors"]["code"] == 2
      #end
    end
  end

  describe "join_room" do
    it "correct" do
      v = @i.create_room(:user => user, :server => "innowhite")
      v = @i.join_meeting("innowhite",v[:data][:room_id], "toto")
      !v["errors"]
    end

    describe "incorrect" do
      it "room id incorrect" do
        v = @i.join_meeting("innowhite", nil, "toto")
        v["errors"] && v["errors"]["code"] == 3
      end

      it "user incorrect" do
        v = @i.join_meeting("innowhite", 1, nil)
        v["errors"] && v["errors"]["code"] == 1
      end
    end
  end

  describe "get_sessions" do
    describe "correct" do
      it "get by user" do
        v = @i.get_sessions(:server => "innowhite")
        !v[:data].blank?
      end

      it "get by tags" do
        v = @i.get_sessions(:server => "innowhite", :tags => "yoyo")
        v[:data] && v[:data].length == 2
      end
    end

    it "incorrect" do
      v = @i.get_sessions()
      v.has_key?("errors")
    end
  end

  describe "schedule_meeting" do
    it "correct" do
      v = @i.schedule_meeting(:server => "innowhite", :user => user, :description => "???", :parentOrg => "ZZZ", :startTime => (DateTime.now - 2.days).to_i, :endTime => (DateTime.now - 1.days).to_i, :timeZone => 2)
      v["data"]
    end

    describe "incorrect" do
      it 'user value missed' do
        v = @i.schedule_meeting(:server => "innowhite")
        v[:errors][:code] == 1
      end

      it 'description value missed' do
        v = @i.schedule_meeting(:server => "innowhite", :user => user)
        v[:errors][:code] == 4
      end

      it 'start time value missed' do
        v = @i.schedule_meeting(:server => "innowhite", :user => user, :description => "???")
        v[:errors][:code] == 5
      end

      it 'end time value missed' do
        v = @i.schedule_meeting(:server => "innowhite", :user => user, :description => "???", :start_time => DateTime.now.to_i)
        v[:errors][:code] == 6
      end

      it 'time zone value missed' do
        v = @i.schedule_meeting(:server => "innowhite", :user => user, :description => "???", :start_time => DateTime.now.to_i, :end_time => DateTime.now.to_i)
        v[:errors][:code] == 7
      end
    end
  end

  describe "past_sessions" do
    it "correct by user" do
      v = @i.past_sessions(:server => "innowhite", :user => user2)
      !v.has_key?("errors")
    end
    #
    #it "correct by tags" do
    #  v = @i.past_sessions(:tags => "2")
    #  v[:data]
    #end

    it "correct without params" do
      v = @i.past_sessions(:server => "innowhite")
      v[:data]
    end
  end

  describe "get_scheduled_list" do
    it "correct by user" do
      v = @i.get_scheduled_list(:server => "innowhite", :user => user2)
      !v.has_key?("errors")
    end
    #
    #it "correct by tags" do
    #  v = @i.get_scheduled_list(:tags => "2")
    #  v[:data]
    #end

    it "correct without params" do
      v = @i.get_scheduled_list(:server => "innowhite")
      v[:data]
    end
  end

  describe "cancel_meeting" do
    it "correct" do
      v = @i.create_room(:server => "innowhite", :user => user)
      @i.cancel_meeting("innowhite", v[:data][:room_id])[:data]
    end

    it "incorrect" do
      !@i.cancel_meeting("innowhite", -1)[:data]
    end
  end

  describe "update_schedule" do
    it "correct" do
      v = @i.create_room(:server => "innowhite", :user => user)
      @i.update_schedule(:server => "innowhite", :room_id => v["room_id"], :description => "huhu")[:data]
    end

    it "incorrect" do
      !@i.update_schedule(:server => "innowhite", :room_id => -1, :description => "huhu")[:data]
    end
  end

  describe "get_video" do
    it "room with video" do
      @i.getRecordingURL(room_with_video).length > 0
    end

    it "room without video" do
      @i.getRecordingURL(room_without_video).blank?
    end
  end
end