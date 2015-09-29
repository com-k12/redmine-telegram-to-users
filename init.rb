require 'redmine'

require_dependency 'redmine_telegram_to_users/listener'

Redmine::Plugin.register :redmine_telegram do
	name 'Redmine Telegram To Users'
	author 'com-k12'
	url 'https://github.com/com-k12/redmine-telegram-to-users'
	author_url 'http://k12.ru'
	description 'Telegram integration'
	version '0.1.0'
  settings :default => {'empty' => true}, :partial => 'settings/telegram_settings'
end
