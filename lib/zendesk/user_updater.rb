module Killbill::Zendesk
  class UserUpdater
    def initialize(client, kb_apis, logger)
      @client = client
      @kb_apis = kb_apis
      @logger = logger
    end

    def update(kb_account_id)
      kb_account = @kb_apis.get_account_by_id(kb_account_id)

      user = find_by_kb_account(kb_account)
      user = create_user(kb_account) if user.nil?

      user.name = kb_account.name
      user.external_id = kb_account.external_key || kb_account.id.to_s
      user.locale = kb_account.locale
      user.timezone = kb_account.time_zone
      user.email = kb_account.email
      user.phone = kb_account.phone
      user.details = "#{kb_account.address1},#{kb_account.address2},#{kb_account.city},#{kb_account.state_or_province},#{kb_account.postal_code},#{kb_account.country}"

      if user.save
        @logger.info "Successfully updated #{user.name} in Zendesk: #{user.url}"
      else
        @logger.warn "Unable to update #{user.name} in Zendesk: #{user.url}"
      end
    end

    def create_user(kb_account)
      # Create the user in Zendesk
      user = @client.users.create(:name => kb_account.name)

      # Save the mapping locally - this is required due to the indexing lag on the Zendesk side,
      # see https://support.zendesk.com/entries/20239737:
      #   When you add new data to your Zendesk, it typically takes about 2 to 3 minutes before it's indexed and can be searched.
      # This is unacceptable for us: if an account creation event is quickly followed by a account update event,
      # we wouldn't be able to retrieve the user, potentially causing duplicates and/or triggering validation errors, e.g.
      #   Email 1370587241-test@tester.com is already being used by another user
      ZendeskUser.create! :kb_account_id => kb_account.id.to_s, :zd_user_id => user.id

      user
    end

    def find_by_kb_account(kb_account)
      zd_account = nil

      # Do we have already a mapping for that user?
      zd_account = find_by_id(kb_account.id.to_s)
      return zd_account if zd_account

      # TODO In the search results below, should we worry about potential dups?

      # First search by external_id, which is the safest method.
      # The external_id is either the account external key...
      zd_account = find_by_external_id(kb_account.external_key) if kb_account.external_key
      return zd_account if zd_account

      # ...or the Kill Bill account id
      zd_account = find_by_external_id(kb_account.id.to_s)
      return zd_account if zd_account

      # At this point, we haven't matched this user yet. To reconcile it, use the email address which is guaranteed
      # to exist on the Zendesk side
      zd_account = find_by_email(kb_account.email) if kb_account.email
      return zd_account if zd_account

      # We couldn't find a match - the account will be created
      nil
    end

    def find_by_id(kb_account_id)
      zd_user = ZendeskUser.find_by_kb_account_id(kb_account_id)
      zd_user ? @client.users.find(:id => zd_user.zd_user_id) : nil
    end

    def find_by_external_id(external_id)
      find_all_by_external_id(external_id).first
    end

    def find_all_by_external_id(external_id)
      @client.search(:query => "type:user external_id:#{external_id}", :reload => true)
    end

    def find_by_email(email)
      find_all_by_email(email).first
    end

    def find_all_by_email(email)
      @client.search(:query => "type:user email:#{email}", :reload => true)
    end
  end
end