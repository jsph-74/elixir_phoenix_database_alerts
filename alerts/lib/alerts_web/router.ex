defmodule AlertsWeb.Router do
  use AlertsWeb, :router
  import Plug.Conn

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :browser_ajax do
    plug :accepts, ["html", "json"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :require_master_password do
    plug AlertsWeb.Plugs.RequireAuth
  end

  # Authentication routes (no auth required)
  scope "/auth", AlertsWeb do
    pipe_through :browser
    
    get("/login", AuthController, :login)
    post("/login", AuthController, :authenticate)
    post("/logout", AuthController, :logout)
  end

  scope "/", AlertsWeb do
    pipe_through [:browser, :require_master_password]

    get("/", AlertController, :index)

    get("/alerts", AlertController, :index)
    get("/alerts/new", AlertController, :new)
    post("/alerts/reboot", AlertController, :reboot)
    post("/alerts/run_all", AlertController, :run_all)

    post("/alerts", AlertController, :create)
    get("/alerts/edit/:uuid", AlertController, :edit)
    put("/alerts/:uuid", AlertController, :update)
    delete("/alerts/:uuid", AlertController, :delete)
    get("/alerts/:uuid", AlertController, :view)
    # Removed old query_diff route - now using inline diffs
    # GET route for run not needed - only POST used
    # GET route for csv not needed - only POST used
    post("/alerts/run/:uuid", AlertController, :run)
    post("/alerts/csv/:uuid", AlertController, :csv)
    post("/alerts/csv_snapshot/:id", AlertController, :csv_snapshot)
    
    # Data source management routes
    get("/data_sources", DataSourceController, :index)
    get("/data_sources/new", DataSourceController, :new)
    post("/data_sources", DataSourceController, :create)
    get("/data_sources/:id", DataSourceController, :show)
    get("/data_sources/:id/edit", DataSourceController, :edit)
    put("/data_sources/:id", DataSourceController, :update)
    delete("/data_sources/:id", DataSourceController, :delete)
    post("/data_sources/:id/test", DataSourceController, :test_connection)
    post("/data_sources/test", DataSourceController, :test_connection_params)
  end

  scope "/", AlertsWeb do
    pipe_through [:browser_ajax, :require_master_password]

    post("/data_sources/test_ajax", DataSourceController, :test_connection_ajax)
  end

  # Other scopes may use custom stacks.
  # scope "/api", AlertsWeb do
  #   pipe_through :api
  # end

  # Legacy authentication function - now replaced by AlertsWeb.Plugs.RequireAuth
  # Kept for reference in case of rollback needs
end
