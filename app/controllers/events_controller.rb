class EventsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index show]
  before_action :concatenate_date, only: %i[create update]
  before_action :correct_user, only: %i[edit update destroy]

  def index
    @events = search(params).paginate(page: params[:page])

    map_hash = Gmaps4rails.build_markers(@events) do |event, marker|
      marker.lat event.latitude
      marker.lng event.longitude
      marker.infowindow render_to_string(partial: '/events/infowindow', locals: { object: event })
    end
    gon.mapHash = map_hash
    @categories = Category.pluck(:name, :id)
  end

  def show
    @event = Event.find(params[:id])
    map_hash = Gmaps4rails.build_markers(@event) do |event, marker|
      marker.lat event.latitude
      marker.lng event.longitude
      marker.infowindow event.venue
    end
    gon.mapHash = map_hash
  end

  def new
    @event = Event.new
  end

  def create
    @event = current_user.events.build(event_params)
    if @event.save
      flash[:success] = 'New event created'
      redirect_to @event
    else
      render 'new'
    end
  end

  def edit
    @event = Event.includes(:creator).find(params[:id])
    if @event.past?
      flash[:danger] = 'You cannot edit past event!'
      redirect_to @event
    end
  end

  def update
    @event = Event.find(params[:id])

    if @event.past?
      flash[:danger] = 'You cannot edit past event!'
      redirect_to @event
    elsif @event.update_attributes(event_params)
      flash[:success] = 'Event updated'
      redirect_to @event
    else
      render 'edit'
    end
  end

  def destroy
    @event = Event.find(params[:id])
    Cloudinary::Api.delete_resources(@event.picture.public_id)
    @event.destroy
    flash[:success] = 'Event deleted'
    redirect_to user_path(current_user)
  end

  def search(params)
    events = Event.includes(:creator, :category)
                  .filter(params.slice(:by_category, :by_title, :start_date, :end_date))
                  .upcoming
                  .by_date
    events = events.near(params[:location]) if params[:location].present?
    events
  end

  private

  def event_params
    params.require(:event).permit(:title, :venue, :date_and_time, :description,
                                  :picture, :user_id, :category_id, :address)
  end

  # Before actions

  def concatenate_date
    params[:event][:date_and_time] = (params[:date] + ' ' + params[:time_submit]).to_datetime
  end

  def correct_user
    @event = Event.find(params[:id])
    if current_user != @event.creator
      redirect_to(root_url)
      flash[:alert] = 'You are not allowed to enter this section!'
    end
  end
end
