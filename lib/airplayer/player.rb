require 'timeout'
require 'uri'
require 'airplay'
require 'airplayer/progress_bar/base'

module AirPlayer
  class Player
    BufferingTimeoutError = Class.new(TimeoutError)

    def initialize
      @airplay     = Airplay::Client.new
      @player      = nil
      @progressbar = nil
      @timeout     = 30
      @interval    = 1
      @total_sec   = 0
      @current_sec = 0
    end

    def play(target)
      path = File.expand_path(target)
      if local_file? path
        video_server = AirPlayer::Server.new(path)
        uri = video_server.uri
        Thread.start { video_server.start }
      else
        uri = URI.encode(target)
      end

      device = @airplay.browse.first
      puts "AirPlay: #{uri} to #{device.name}(#{device.ip})"

      @progressbar = ProgressBar.create(:format => '   %a |%b%i| %p%% %t', :title => :Waiting)
      @player = @airplay.send_video(uri)
      buffering
      while playing do
        @progressbar.progress = @current_sec
      end
      stop
    rescue BufferingTimeoutError
      abort 'Buffering timeout error.'
    end

    def stop
      unless @player.nil?
        @player.stop
      end

      unless @progressbar.nil?
        @progressbar.title = :Complete
        @progressbar.finish
      end
    end

    private
      def local_file?(path)
        File.exist? path
      end

      def buffering
        timeout @timeout, BufferingTimeoutError do
          loop do
            playing
            redo unless buffering?
            @progressbar.title = :Streaming
            @progressbar.total = @total_sec
            break
          end
        end
      end

      def playing
        scrub = @player.scrub
        @total_sec   = scrub['duration']
        @current_sec = scrub['position']
        sleep @interval
        progress?
      end

      def progress?
        0 < @current_sec && @current_sec < @total_sec
      end

      def buffering?
        0 < @total_sec && 0 < @current_sec
      end
  end
end
