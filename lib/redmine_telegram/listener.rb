require 'httpclient'
require 'active_resource'

class SlackListener < Redmine::Hook::Listener

	def controller_issues_new_after_save(context={})

		$stdout = File.open('f_controller_issues_new_after_save_telegram.txt', 'a')
		$stderr = File.open('f_err_controller_issues_new_after_save_telegram.txt', 'a')

    p context
    return

		issue = context[:issue]

		journal = issue.current_journal
		p "journal", journal

		if journal != nil then

			to = journal.notified_users
			cc = journal.notified_watchers
			watchers = to | cc
			cu = User.current
			if cu.pref.no_self_notified == true then
				watchers.delete(cu)
			end
			for user in watchers
				cv = User.find_by_mail(user[:mail]).custom_value_for(2)
				next unless cv
				slack_users.push(cv.value)
			end

		else

			cu = User.current
			recipients = issue.recipients
			for mail in recipients
				us = User.find_by_mail(mail)

				if us == cu && cu.pref.no_self_notified == true then
					next
				end

				cv = us.custom_value_for(2)
				puts cv, cv.class
				next unless cv
				slack_users.push(cv.value)
			end

		end

		p slack_users
		slack_users.map{|user| (speak msg, user)}

	end

	def controller_issues_edit_after_save(context={})
		$stdout = File.open('f_controller_issues_edit_after_save_telegram.txt', 'a')

		issue = context[:issue]
		journal = context[:journal]

    p "\n\n\n\n"
    p object_url issue
    p issue.subject
    p journal

    return
		url = url_for_project issue.project
		return unless url

		msg = issue.project + journal.user.to_s + "updated" + issue

    p msg
    return

		to = journal.notified_users
    cc = journal.notified_watchers
		watchers = to | cc
		cu = User.current
		if cu.pref.no_self_notified == true then
			watchers.delete(cu)
		end
		slack_users = []
		for user in watchers
			cv = User.find_by_mail(user[:mail]).custom_value_for(2)
			next unless cv
			slack_users.push(cv.value)
		end
		p watchers, slack_users
		slack_users.map{|user| (speak msg, user)}
	end



	def speak(msg, user)
    $stdout = File.open('f_controller_speak_telegram.txt', 'a')

    url = Setting.plugin_redmine_telegram[:telegram_url] if not url

    f = File.new("../../source")
    my_hash = JSON.parse(f.read)
    f.close
    user = my_hash[user]

    p user

    return unless user

		params = {
      :chat_id => user,
			:text => msg
		}

    p params

		client = HTTPClient.new
		client.ssl_config.cert_store.set_default_paths
		client.ssl_config.ssl_version = "SSLv23"
		client.post url, {:payload => params.to_json}
  end

private
	def object_url(obj)
		Rails.application.routes.url_for(obj.event_url({:host => Setting.host_name, :protocol => Setting.protocol}))
	end
end