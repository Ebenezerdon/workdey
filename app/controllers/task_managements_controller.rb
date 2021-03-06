class TaskManagementsController < ApplicationController
  before_action :login_required, :show_notification_count,
                only: [:index, :new, :show, :review_and_rate]

  def new
    if params.except(:controller, :action).empty?
      redirect_to(dashboard_path) && return
    end
    @artisan_id = deobfuscate(params.except(:controller, :action))["id"]
    @artisan = User.find(@artisan_id) if @artisan_id
    @task = TaskManagement.new
  end

  def show
    @task = TaskManagement.find(params[:id])
  end

  def create
    @task = TaskManagement.new(task_details.except(:task_name))
    @task.task_id = Skillset.find_by(name: task_details[:task_name].capitalize).
                    id
    @task.start_time = get_time(:start)
    @task.end_time = get_time(:end)
    if @task.save
      session.delete(:searcher)
      flash.clear
      flash.now[:notice] = "Your task has been created"
      render "show"
    else
      retain_form_values
      redirect_to assign_task_path(obfuscate(id: @task.artisan_id))
    end
  end

  def index
    @tasks = if current_user.artisan?
               sort_status(current_user.tasks_given.paid_for)
             elsif current_user.tasker?
               sort_status(
                 current_user.tasks_created +
                 current_user.tasks_assigned.unassigned
               ).paginate(page: params[:page], per_page: 10)
             end
  end

  def update
    id = params[:task_id]
    if TaskManagement.find(id).update_attribute(:status, "done")
      if review_and_rate(params)
        flash[:notice] = "Task is completed and your review has been recorded."
      else
        flash[:notice] = "Task is completed."
      end
    else
      flash[:alert] = "Operation failed."
    end
    redirect_to dashboard_path
  end

  def send_email_notifications(task)
    return unless current_user.enable_notifications
    notif_artisan = User.find(task.artisan_id)
    notif_tasker = User.find(task.tasker_id)
    task_category = Task.find(task.task_id)
    NotificationMailer.send_notifications(
      current_user,
      task,
      task_category,
      notif_tasker,
      notif_artisan
    ).deliver_now
  end

  def share
    task = TaskManagement.find(params[:id])
    task.update_attribute("shared", true)
    notify_tasker(task)
    render json: { message: "success" }
  end

  private

  def task_details
    params.require(:task_management).
      permit(:task_name, :tasker_id, :artisan_id, :amount, :description)
  end

  def task_date
    params.require(:date).permit(:month, :day)
  end

  def task_time
    params.require(:time_range).permit(:task)
  end

  def get_time(time_period)
    current_year = Time.now.getlocal.year
    month = task_date[:month].to_i
    day = task_date[:day].to_i

    return nil if day < Time.now.getlocal.day

    if time_period == :start
      time = parse range(task_time[:task]).first
    end

    if time_period == :end
      time = parse range(task_time[:task]).last
    end

    Time.new(current_year, month, day, time)
  end

  def range(str)
    str.gsub(/[^0-9\-(a|p)m]/, "").split("-")
  end

  def parse(str_time)
    DateTime.parse(str_time).strftime("%H").to_i
  end

  def retain_form_values
    flash[:errors] = @task.errors.full_messages
    flash[:amount] = task_details[:amount]
    flash[:description] = task_details[:description]
    flash[:month] = task_date[:month]
    flash[:day] = task_date[:day]
    flash[:time] = task_time[:task]
  end

  def review_and_rate(params)
    review = Review.new
    if params[:user_id] && current_user.id
      review.rating = params[:rating] if params[:rating]
      review.reviewer_id = current_user.id
      review.user_id = params[:user_id]
      review.review = params[:comment] if params[:comment]
      return "success" if review.save
    end
  end

  def sort_status(tasks)
    complete_tasks = []
    incomplete_tasks = []
    tasks.each do |task|
      task.status == "done" ? complete_tasks << task : incomplete_tasks << task
    end
    complete_tasks + incomplete_tasks
  end

  def notify_tasker(task)
    NotificationMailer.send_contact_info(task.tasker, task.artisan).deliver_now
    Notification.create(
      message: "#{task.artisan.fullname} has shared contact with you!",
      sender_id: task.artisan_id,
      receiver_id: task.tasker_id,
      notifiable: task
    ).notify_receiver("broadcast_task")
  end
end
