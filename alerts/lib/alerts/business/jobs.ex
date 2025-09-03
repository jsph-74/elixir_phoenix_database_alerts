defmodule Alerts.Business.Jobs do
  alias Alerts.Scheduler
  alias Alerts.Business.DB

  def get_quantum_config(job_name, task, schedule) do
    %Quantum.Job{
      name: job_name,
      overlap: false,
      run_strategy: %Quantum.RunStrategy.Random{nodes: :cluster},
      schedule: Crontab.CronExpression.Parser.parse!(schedule),
      task: task,
      state: :active,
      timezone: "Europe/Zurich"
    }
  end

  def save(job_name, _task, nil), do: job_name
  def save(job_name, _task, ""), do: job_name

  def save(job_name, task, schedule) do
    :ok =
      Scheduler.new_job()
      |> Quantum.Job.set_name(job_name)
      |> Quantum.Job.set_overlap(false)
      |> Quantum.Job.set_run_strategy(%Quantum.RunStrategy.Random{nodes: :cluster})
      |> Quantum.Job.set_schedule(Crontab.CronExpression.Parser.parse!(schedule))
      |> Quantum.Job.set_task(task)
      |> Quantum.Job.set_state(:active)
      |> Quantum.Job.set_timezone("Europe/Zurich")
      |> Scheduler.add_job()

    job_name
  end

  def update(job_name, task, schedule) do
    job_name
    |> delete()
    |> save(task, schedule)
  end

  def delete(job_name) do
    :ok = Scheduler.delete_job(job_name)
    job_name
  end

  # Alert-specific job functions

  def get_alert_job_name(%DB.Alert{} = alert),
    do: get_alert_job_name(alert.alert_public_id)

  def get_alert_job_name(alert_public_id) when is_binary(alert_public_id),
    do: "alert_#{alert_public_id}" |> String.to_atom()

  def get_alert_job_name(alert_id) when is_integer(alert_id),
    do: "alert_#{alert_id}" |> String.to_atom()

  defp get_alert_function_definition(%DB.Alert{} = alert),
    do: {Alerts.Business.Alerts, :run_by_history_id, [alert.alert_public_id]}

  def save_alert_job(%DB.Alert{schedule: nil} = alert),
    do: alert

  def save_alert_job(%DB.Alert{schedule: ""} = alert),
    do: alert

  def save_alert_job(%DB.Alert{} = alert) do
    alert
    |> get_alert_job_name()
    |> save(fn -> Alerts.Business.Alerts.run_by_history_id(alert.alert_public_id) end, alert.schedule)

    alert
  end

  def get_alert_quantum_config(%DB.Alert{} = alert) do
    get_quantum_config(
      get_alert_job_name(alert),
      get_alert_function_definition(alert),
      alert.schedule
    )
  end

  def update_alert_job(alert) do
    alert
    |> delete_alert_job()
    |> save_alert_job()

    alert
  end

  def delete_alert_job(alert) do
    alert
    |> get_alert_job_name()
    |> delete()

    alert
  end
end
