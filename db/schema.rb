require 'active_record'

ActiveRecord::Schema.define(:version => 20130606153635) do
  create_table 'zendesk_users', :force => true do |t|
    t.string 'kb_account_id', :null => false
    t.integer 'zd_user_id', :null => false
    t.datetime 'created_at', :null => false
    t.datetime 'updated_at', :null => false
  end

  add_index(:zendesk_users, :kb_account_id, :unique => true)
  add_index(:zendesk_users, :zd_user_id, :unique => true)
end
