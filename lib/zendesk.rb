require 'active_record'
require 'sinatra'

require 'killbill'
require 'zendesk_api'

require 'zendesk/zendesk_user'
require 'zendesk/user_updater'
require 'zendesk/user_updater_initializer'

module Killbill::Zendesk
  class ZendeskPlugin < Killbill::Plugin::Notification

    # For testing
    attr_reader :updater

    def start_plugin
      super
      @updater = Killbill::Zendesk::UserUpdaterInitializer.instance.initialize!(@conf_dir, @kb_apis, @logger)
    end

    def on_event(event)
      @updater.update(event.account_id) if [:ACCOUNT_CREATION, :ACCOUNT_CHANGE].include?(event.event_type.enum)
    end
  end
end
