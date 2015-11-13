# encoding: UTF-8
require 'httpclient'
require 'active_resource'

class SlackListener < Redmine::Hook::Listener

	def controller_issues_new_after_save(context={})

		# $stdout = File.open('f_controller_issues_new_after_save_telegram.txt', 'a')
		# $stderr = File.open('f_err_controller_issues_new_after_save_telegram.txt', 'a')

		$stdout = File.open('f_controller_issues_edit_after_save_telegram.txt', 'a')

		p "KEYS", context.keys()

    issue = context[:issue]
    url = Setting.plugin_redmine_telegram[:telegram_url] if not url
		return unless url

		journal = issue.current_journal
		responsible_user = issue.custom_field_values[0]

		responsible_user_name = "-"
		if journal != nil then
			for user in journal.project.users
				if user[:id] == responsible_user.value.to_i then
					responsible_user_name = "#{escape(user[:firstname])} #{escape(user[:lastname])}"
				end
			end
		end

		msg = "*Задача*: \"#{issue.subject}\"\n#{object_url issue}\n*Статус*: #{escape(issue.status.to_s)}\n*Приоритет*: #{escape(issue.priority.to_s)}\n*Назначена на*: #{escape(issue.assigned_to.to_s)}\n*Ответственный*: #{responsible_user_name}"



    telegram_users = []
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
				telegram_users.push(cv.value)
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
				telegram_users.push(cv.value)
			end

		end


		telegram_users.map{|user| (speak msg, user, url)}

	end

	def controller_issues_edit_after_save(context={})
		begin

			$stdout = File.open('f_controller_issues_edit_after_save_telegram.txt', 'a')

			issue = context[:issue]
			journal = context[:journal]

			# get telegram API url from plugin settings
			url = Setting.plugin_redmine_telegram[:telegram_url] if not url
			return unless url


			responsible_user = issue.custom_field_values[0]
			responsible_user_data = nil
			responsible_user_name = "-"
			if journal != nil then
				for user in journal.project.users
					if user[:id] == responsible_user.value.to_i then
						responsible_user_data = user
						responsible_user_name = "#{escape(user[:firstname])} #{escape(user[:lastname])}"
					end
				end
			end

			# form message
			msg = "*Задача*: \"#{issue.subject}\"\n#{object_url issue}\n*Обновлена*: #{escape journal.user.to_s}\n"

			for d in journal.details
				if d[:prop_key] == 4 then
					msg += "*#{detail_to_field(d)[:title]}*: #{responsible_user_name}\n"
				else
					msg+="*#{detail_to_field(d)[:title]}*: #{detail_to_field(d)[:value]}\n"
				end
			end

			if journal.notes != "" then
				msg += "*Комментарий*: \"#{escape journal.notes}\""
			end


			# get watchers, notified users
			to = journal.notified_users
			cc = journal.notified_watchers
			watchers = to | cc
			if responsible_user_data != nil then
				watchers.push(responsible_user_data)
			end

			cu = User.current
			if cu.pref.no_self_notified == true then

				watchers.delete(cu)

			end

			# get telegram username from user profile settings
			telegram_users = []
			for user in watchers

				cv = User.find_by_mail(user[:mail]).custom_value_for(2)
				next unless cv

				telegram_users.push(cv.value)

			end


			# send message
			telegram_users.map{|user| (speak msg, user, url)}

		rescue => detail

        $stdout = File.open('redmine-telegram.exc', 'a')
        p detail, detail.backtrace
		end

	end



	def speak(msg, user, url)
    begin

      f = File.new("address_book")
      my_hash = JSON.parse(f.read)
      f.close

      user = my_hash[user]
      return unless user


      params = {
        :chat_id => user.to_i,
        :text => msg,
        :parse_mode => "Markdown"
      }




      client = HTTPClient.new
      client.send_timeout = 2
      client.receive_timeout = 2
      client.ssl_config.cert_store.set_default_paths
      client.ssl_config.ssl_version = "SSLv23"
      client.post url, params

    rescue => detail

        $stdout = File.open('redmine-telegram.exc', 'a')
        p detail, detail.backtrace

    end


  end

private
  def escape(msg)
		msg.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
  end

	def object_url(obj)
		Rails.application.routes.url_for(obj.event_url({:host => Setting.host_name, :protocol => Setting.protocol}))
	end
end