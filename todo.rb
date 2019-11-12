require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

def next_list_id(lists)
  max = lists.map { |list| list[:id] }.max || 0
  max + 1
end

post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_list_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = 'This list has been created.'
    redirect '/lists'
  end
end

get '/lists/new' do
  erb :new_list, layout: :layout
end

get '/lists/:id' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)

  erb :list, layout: :layout
end

# Update an existing todo list
post '/lists/:id' do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)

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
  @list = load_list(id)
  erb :edit_list, layout: :layout
end

# Delete a todo list
post '/lists/:id/destroy' do
  id = params[:id].to_i

  # Instead of deleting at index, we want to delete the hash that contains id
  # session[:lists].delete_at(id)
  session[:lists].reject! { |list| list[:id] == id }
  session[:success] = "The list has been deleted."

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    redirect "/lists"
  end
end

def next_todo_id(todos)
  max = todos.map { |todo| todo[:id] }.max || 0
  max + 1
end

# Add a new todo item to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_todo_id(@list[:todos])
    @list[:todos] << { id: id, name: text, completed: false }

    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Complete a todo item in a list
post '/lists/:list_id/todos/:id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  todo_index = @list[:todos].index { |todo| todo[:id] == todo_id }

  is_completed = params[:completed] == "true"
  @list[:todos][todo_index][:completed] = is_completed

  session[:success] = "The todo item has been updated."
  redirect "/lists/#{@list_id}"
end

# Complete all todo items in the list
post '/lists/:id/complete_all' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)

  @list[:todos].each do |todo|
    todo[:completed] = "true"
  end

  session[:success] = "All todo items have been updated."
  redirect "/lists/#{@list_id}"
end

# Delete a todo item from a list
post '/lists/:list_id/todos/:todo_id/destroy' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  @list[:todos].reject! { |todo| todo[:id] == todo_id }

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo item has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

helpers do
  def list_complete?(list)
    undone_todos(list) == 0 && todos_count(list) > 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def undone_todos(list)
    list[:todos].select { |todo| !todo[:completed] }.size
  end

  def todos_count(list)
    list[:todos].size
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end

def load_list(list_id)
  # list = session[:lists][index] if index && session[:lists][index]
  list = session[:lists].find { |list| list[:id] == list_id }
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
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
