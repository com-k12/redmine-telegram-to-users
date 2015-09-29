require 'redmine'

require_dependency 'redmine_telegram/listener'

Redmine::Plugin.register :redmine_telegram do
	name 'Redmine Telegram To Users'
	author 'com-k12'
	url 'https://github.com/com-k12/redmine-telegram-to-users'
	author_url 'http://k12.ru'
	description 'Telegram integration'
	version '1.0'

  settings \
  :default => {
			'telegram_url' => 'https://api.telegram.org/bot{token}/sendMessage',
		},
		:partial => 'settings/telegram_settings'

end
