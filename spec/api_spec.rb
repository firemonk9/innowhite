require File.expand_path(File.join(File.dirname(__FILE__), "..", "lib", "socnetapi"))

describe Innowhite do
  before do
    #@config = YAML::load(File.open(File.join(File.dirname(__FILE__), "config.yml")))
    @i = Innowhite.new
  end
  
  describe "create_room" do
    it "correct" do
      v = @i.create_room(:user => "jb")
      v.is_a?(Hash) && v.has_key?(:room_id) && v.has_key?(:address)
    end

    it "incorrect" do
      v = @i.create_room
      v.is_a?(String)
    end
  end

  describe "join_room" do
    it "correct" do
      v = @i.create_room(:user => "jb")
      v = @i.join_meeting(v[:room_id], "toto")
      (v=~ /JoinRoom/) != nil
    end

    it "incorrect" do
      @i.join_meeting(-1, "toto").nil?
    end
  end

  describe "schedule_meeting" do
    it "correct" do
      @i.schedule_meeting(:user => "jb", :description => "???", :parentOrg => "ZZZ", :startTime => (DateTime.now - 2.days).to_i, :endTime => (DateTime.now - 1.days).to_i, :timeZone => 2)
    end

    it "incorrect" do
      !@i.schedule_meeting(:user => "jb", :description => "???")
    end
  end

  describe "get_sessions" do
    it "correct" do
      v = @i.get_sessions(:parentOrg => "GGG")
      v.is_a?(Hash)
    end

    it "incorrect" do
      v = @i.get_sessions()
      v.is_a?(String)
    end
  end

  describe "past_sessions" do
    it "correct" do
      v = @i.past_sessions(:parentOrg => "GGG")
      v.is_a?(Hash)
    end

    it "incorrect" do
      v = @i.past_sessions()
      v.is_a?(String)
    end
  end

  describe "get_scheduled_list" do
    it "correct" do
      v = @i.get_scheduled_list(:parentOrg => "GGG")
      v.is_a?(Hash)
    end

    it "incorrect" do
      v = @i.get_scheduled_list()
      !v.is_a?(Hash)
    end
  end

  describe "cancel_meeting" do
    it "correct" do
      v = @i.create_room(:user => "jb")
      @i.cancel_meeting(v[:room_id])
    end

    it "incorrect" do
      !@i.cancel_meeting(-1)
    end
  end

  describe "update_schedule" do
    it "correct" do
      v = @i.create_room(:user => "jb")
      @i.update_schedule(:room_id => v[:room_id], :description => "huhu")
    end

    it "incorrect" do
      @i.update_schedule(:room_id => -1, :description => "huhu")
    end
  end

  it "get_video"
end
