require_relative '../util'

require 'aws-sdk-iam'

DEFAULT_KEY_AGE = 90
Aws.config.update(:http_proxy => ENV['https_proxy'])

class Rotator

  def rotate
    keys = yaml('auth-keys')
    path = to_path(act_acc)
    current_key = keys['accounts'].dig(*path)
    puts "Current account #{white(act_acc)}"

    unless current_key
      puts red("You need to authenticate to userstore account to rotate keys.")
      exit(1)
    end
    puts "Current key #{white(current_key['key_id'])}"

    iam = Aws::IAM::Client.new(region: region)

    account_keys = iam.list_access_keys.access_key_metadata

    key_to_rotate = account_keys.select {|k| k.access_key_id == current_key['key_id']}.first

    unless key_to_rotate
      puts red("Key #{current_key['key_id']} for account #{ act_acc } doesn't exist in AWS.")
      exit(1)
    end

    if account_keys.size > 1
      puts "You have #{white(account_keys.size)} keys already. Remove other keys before trying to rotate."
      account_keys.each do |k|
        key = k.access_key_id == current_key['key_id'] ? "#{white(k.access_key_id)} <-- Keep" : "#{red(k.access_key_id)} <-- Remove"
        puts key
      end
      exit(1)
    end

    key_age_days = ((Time.now - key_to_rotate.create_date)/3600/24).round
    puts "The key is #{white(key_age_days)} days old."

    if key_age_days < DEFAULT_KEY_AGE
      puts green('All good.')
      exit(0)
    else
      puts 'Key needs rotation.'
    end

    new_key = iam.create_access_key()
    current_key['key_id'] = new_key.access_key.access_key_id
    current_key['secret_key'] = new_key.access_key.secret_access_key

    puts "New key #{white(current_key['key_id'])} was created"

    dump(keys, 'auth-keys')

    account_keys.each do |k|
      puts "Removing old key #{white(k.access_key_id)}"
      iam.delete_access_key(access_key_id: k.access_key_id)
    end

    puts green('Key was rotated successfully.')
  end
end

#Rotator.new.rotate