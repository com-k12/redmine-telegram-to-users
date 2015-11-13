# encoding: UTF-8
require 'httpclient'
require 'active_resource'

class SlackListener < Redmine::Hook::Listener

	def controller_issues_new_after_save(context={})

		# $stdout = File.open('f_controller_issues_new_after_save_telegram.txt', 'a')
		# $stderr = File.open('f_err_controller_issues_new_after_save_telegram.txt', 'a')


    issue = context[:issue]
    url = Setting.plugin_redmine_telegram[:telegram_url] if not url
		return unless url


		msg = "*Задача*: \"#{issue.subject}\"\n#{object_url issue}\n*Статус*: #{escape(issue.status.to_s)}\n*Приоритет*: #{escape(issue.priority.to_s)}\n*Назначена на*: #{escape(issue.assigned_to.to_s)}"
		journal = issue.current_journal


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


			# form message
			msg = "*Задача*: \"#{issue.subject}\"\n#{object_url issue}\n*Обновлена*: #{escape journal.user.to_s}\n"
			journal.details.map { |d| msg+="*#{detail_to_field(d)[:title]}*: #{detail_to_field(d)[:value]}\n" }

			if journal.notes != "" then

				msg += "*Комментарий*: \"#{escape journal.notes}\""

			end


			# get watchers, notified users
			to = journal.notified_users
			cc = journal.notified_watchers
			watchers = to | cc

			p "watchers 1", watchers

			begin
				responsible_user = issue.custom_field_values[0]
				for user in journal.project.users

					p "user", user[:id], responsible_user

					if user[:id] == responsible_user then
						watchers.push(user)
					end
				end
			rescue => detail
				 p "detail", detail.backtrace
			end

			p "wathers 2", watchers

			cu = User.current
			if cu.pref.no_self_notified == true then

				watchers.delete(cu)

			end

			p "wathers 3", watchers

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