require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

get '/lists' do
  @lists = session[:lists]
  p @lists
  erb :lists, layout: :layout
end

post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'This list has been created.'
    redirect '/lists'
  end
end

get '/lists/new' do
  erb :new_list, layout: :layout
end

get '/lists/:id' do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]

  # p @list
  erb :list, layout: :layout
end

# Update an existing todo list
post '/lists/:id' do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = session[:lists][id]

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'This list has been updated.'
    redirect "/lists/#{id}"
  end
end

# Edit an existing todo list
get '/lists/:id/edit' do
  id = params[:id].to_i
  @list = session[:lists][id]
  erb :edit_list, layout: :layout
end

# Delete a todo list
post '/lists/:id/destroy' do
  id = params[:id].to_i
  session[:lists].delete_at(id)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Add a new todo item to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: text, completed: false }
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Complete a todo item in a list
post '/lists/:list_id/todos/:id' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  todo_id = params[:id].to_i
  is_completed = params[:completed] == "true"
  @list[:todos][todo_id][:completed] = is_completed

  session[:success] = "The todo item has been updated."
  redirect "/lists/#{@list_id}"
end

# Complete all todo items in the list
post '/lists/:id/complete_all' do
  # get list id
  # get list
  # get todos
  # loop through todos
  #   set each todo to "true"
  # redirect to "/lists/list_id"

  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]

  @list[:todos].each do |todo|
    todo[:completed] = "true"
  end

  session[:success] = "All todo items have been updated."
  redirect "/lists/#{@list_id}"
end

# Delete a todo item from a list
post '/lists/:list_id/todos/:todo_id/destroy' do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  session[:lists][list_id][:todos].delete_at(todo_id)
  session[:success] = "The todo item has been deleted."
  redirect "/lists/#{list_id}"
end

helpers do
  def list_complete?(list)
    # Loop through list
    #   Check to see if each item is completed

    # If all items are is_completed
    #   Return class complete
    # Else
    #   Return ''
    undone_todos(list) == 0 && todos_count(list) > 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def undone_todos(list)
    # list.count { |todo| todo[:completed] == false }
    list[:todos].select { |todo| !todo[:completed] }.size
  end

  def todos_count(list)
    list[:todos].size
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }

    # Input: an array of hashes
    # lists.each_with_index do |list, index|
    #   if list_complete?(list)
    #     complete_lists[list] = index
    #   else
    #     incomplete_lists[list] = index
    #   end
    # end

    # incomplete_lists.each(&block)
    # complete_lists.each(&block)

    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    # Input: an array of hashes
    # todos.each_with_index do |todo, index|
    #   if todo[:completed]
    #     complete_todos[todo] = index
    #   else
    #     incomplete_todos[todo] = index
    #   end
    # end

    # incomplete_todos.each(&block)
    # complete_todos.each(&block)

    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
end

# Return an error message if name is invalid. Otherwise return nil.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'List name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique.'
  end
end

def error_for_todo(name)
  if !(1..100).cover? name.size
    'Todo must be between 1 and 100 characters.'
  end
end
