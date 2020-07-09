require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sinatra/content_for"

configure do 
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

helpers do
  def h(content)
    Rack::Utils.escape_html(content)
  end
  
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end
  
  def list_class(list)
    "complete" if list_complete?(list)
  end
  
  def todos_count(list)
    list[:todos].size
  end
  
  def todos_remaining_count(list)
    list[:todos].select { |todo| !todo[:completed] }.size
  end
  
  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }
    
    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end
  
  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }
    
    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
end

before do 
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View all the lists
get "/lists" do
  @list = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid. Return nil if the name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "The list name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "The list name must be unique."
  end
end

# Determine next id to assign to a todo list
def next_list_id(lists)
  max = lists.map { |list| list[:id] }.max || 0
  max + 1
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  id = next_list_id(session[:lists])
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << {id: id, name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# loads a list by a given id or else returns an error and redirects 
def load_list(id)
  list = session[:lists].find { |list| list[:id] == id }
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end
# Information for a single to do list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :list_template, layout: :layout
end

# Edit an existing todo list
get "/lists/:id/edit" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :edit_list
end

# Update an existing to do list
post "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  list_name = params[:list_name].strip
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo list
post "/lists/:id/destroy" do
  id = params[:id].to_i
  session[:lists].delete_if { |list| list[:id] == id }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

# Return an error message if the name is invalid. Return nil if valid.
def error_for_todo(name)
  if !(1..100).cover? name.size
    "Todo name must be between 1 and 100 characters."
  end
end

# Determine next id to assign to a todo list
def next_todo_id(todos)
  max = todos.map { |todo| todo[:id] }.max || 0
  max + 1
end

# Add a todo item to a todo list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo = params[:todo].strip
  
  error = error_for_todo(todo)
  if error
    session[:error] = error
    erb :list_template, layout: :layout
  else
    id = next_todo_id(@list[:todos]) # change later
    @list[:todos] << {id: id, name: todo, completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a todo list
post "/lists/:list_id/todos/:id/destroy" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  id = params[:id].to_i
  
  @list[:todos].delete_if { |todo| todo[:id] == id }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "Todo removed"
    redirect "/lists/#{@list_id}"
  end
end

# Mark a single todo as completed or not completed
post "/lists/:list_id/todos/:id" do 
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  
  id = params[:id].to_i
  is_completed = params[:completed] == "true"
  @list[:todos].each { |todo| todo[:completed] = is_completed if todo[:id] == id }
  session[:success] = "Todo was updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todo as complete
post "/lists/:id/complete_all" do
  @id = params[:id].to_i
  @list = load_list(@id)

  @list[:todos].each { |todo| todo[:completed] = true }

  session[:success] = "All todos complete."
  redirect "/lists/#{@id}"
end
