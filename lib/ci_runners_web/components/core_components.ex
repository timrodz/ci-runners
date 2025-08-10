defmodule CiRunnersWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: CiRunnersWeb.Gettext

  alias Phoenix.LiveView.{JS, ColocatedHook, ColocatedJS}

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark-solid" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch)
  attr :variant, :string, values: ~w(primary)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{"primary" => "btn-primary", nil => "btn-primary btn-soft"}
    assigns = assign(assigns, :class, Map.fetch!(variants, assigns[:variant]))

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={["btn", @class]} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={["btn", @class]} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               range search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <fieldset class="fieldset mb-2">
      <label>
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <span class="fieldset-label">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class="checkbox checkbox-sm"
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <fieldset class="fieldset mb-2">
      <label>
        <span :if={@label} class="fieldset-label mb-1">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={["w-full select", @errors != [] && "select-error"]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <fieldset class="fieldset mb-2">
      <label>
        <span :if={@label} class="fieldset-label mb-1">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={["w-full textarea", @errors != [] && "textarea-error"]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <fieldset class="fieldset mb-2">
      <label>
        <span :if={@label} class="fieldset-label mb-1">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={["w-full input", @errors != [] && "input-error"]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
      <.icon name="hero-exclamation-circle-mini" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4", @class]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-base-content/70">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}>
            <span class="sr-only">{gettext("Actions")}</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-row">
        <div>
          <div class="font-bold">{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  @doc """
  Renders a status badge for workflow runs and jobs.

  ## Examples

      <.status_badge status="in_progress" />
      <.status_badge status="completed" conclusion="success" />
      <.status_badge status="completed" conclusion="failure" />
  """
  attr :status, :string, required: true, doc: "the status of the workflow/job"
  attr :conclusion, :string, default: nil, doc: "the conclusion when status is completed"
  attr :class, :string, default: "", doc: "additional CSS classes"

  def status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
      status_badge_class(@status, @conclusion),
      @class
    ]}>
      {status_badge_text(@status, @conclusion)}
    </span>
    """
  end

  @doc """
  Renders a workflow run card with run details and jobs.

  ## Examples

      <.workflow_run_card workflow_run={run} jobs={jobs} />
  """
  attr :workflow_run, :any, required: true, doc: "the workflow run struct"
  attr :jobs, :list, default: [], doc: "list of jobs for this workflow run"
  attr :class, :string, default: "", doc: "additional CSS classes"

  def workflow_run_card(assigns) do
    ~H"""
    <div id="workflow-run-card" class={["bg-base-200 shadow-md rounded-lg overflow-hidden", @class]}>
      <div class="px-6 py-4 border-b border-base-300">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-3">
            <%= if Ecto.assoc_loaded?(@workflow_run.repository) do %>
              <.link
                href={
                  github_workflow_run_url(
                    @workflow_run.repository.owner,
                    @workflow_run.repository.name,
                    @workflow_run.github_id
                  )
                }
                target="_blank"
                class="github-link-external"
              >
                <h3 class="text-lg font-medium text-base-content">
                  {@workflow_run.name}
                </h3>
                <.icon name="hero-arrow-top-right-on-square" class="h-4 w-4 text-base-content/60" />
              </.link>
            <% else %>
              <h3 class="text-lg font-medium text-base-content">
                {@workflow_run.name}
              </h3>
            <% end %>
            <.status_badge status={@workflow_run.status} conclusion={@workflow_run.conclusion} />
          </div>
          <div class="text-sm text-base-content/60">
            #{@workflow_run.run_number}
          </div>
        </div>

        <div class="mt-2 flex items-center space-x-6 text-sm text-base-content/60">
          <%= if Ecto.assoc_loaded?(@workflow_run.repository) do %>
            <.link
              href={github_repo_url(@workflow_run.repository.owner, @workflow_run.repository.name)}
              target="_blank"
              class="github-link"
            >
              <.icon name="hero-building-office" class="mr-1.5 h-4 w-4 text-base-content/50" />
              {@workflow_run.repository.owner}/{@workflow_run.repository.name}
            </.link>
          <% end %>

          <div class="flex items-center">
            <.icon name="hero-clock" class="mr-1.5 h-4 w-4 text-base-content/50" />
            <.relative_time datetime={@workflow_run.started_at} />
            <%!-- <span>{time_ago(@job.started_at)}</span> --%>
          </div>

          <div class="flex items-center">
            <.icon name="hero-code-bracket" class="mr-1.5 h-4 w-4 text-base-content/50" />
            <%= if Ecto.assoc_loaded?(@workflow_run.repository) do %>
              <.link
                href={
                  github_branch_url(
                    @workflow_run.repository.owner,
                    @workflow_run.repository.name,
                    @workflow_run.head_branch
                  )
                }
                target="_blank"
                class="github-link"
              >
                {@workflow_run.head_branch}
              </.link>
            <% else %>
              <span class="text-base-content">{@workflow_run.head_branch}</span>
            <% end %>
          </div>

          <div class="flex items-center">
            <.icon name="hero-hashtag" class="mr-1.5 h-4 w-4 text-base-content/50" />
            <%= if Ecto.assoc_loaded?(@workflow_run.repository) do %>
              <.link
                href={
                  github_commit_url(
                    @workflow_run.repository.owner,
                    @workflow_run.repository.name,
                    @workflow_run.head_sha
                  )
                }
                target="_blank"
                class="github-link"
              >
                {String.slice(@workflow_run.head_sha, 0, 7)}
              </.link>
            <% else %>
              <span class="text-base-content">{String.slice(@workflow_run.head_sha, 0, 7)}</span>
            <% end %>
            <.copy_button text={@workflow_run.head_sha} class="ml-2">
              <.icon
                name="hero-clipboard"
                class="mr-1.5 h-4 w-4 text-base-content/50 hover:text-base-content"
              />
            </.copy_button>
          </div>
        </div>
      </div>

      <%= if @jobs != [] do %>
        <div class="px-6 py-4">
          <h4 class="text-sm font-medium text-base-content mb-3">Jobs</h4>
          <div class="space-y-2">
            <%= for job <- Enum.sort_by(@jobs, & &1.started_at, {:desc, DateTime}) do %>
              <.workflow_job_item job={job} workflow_run={@workflow_run} />
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a workflow job item with job details.

  ## Examples

      <.workflow_job_item job={job} workflow_run={workflow_run} />
  """
  attr :job, :any, required: true, doc: "the workflow job struct"
  attr :workflow_run, :any, required: true, doc: "the workflow run struct"
  attr :class, :string, default: "", doc: "additional CSS classes"

  def workflow_job_item(assigns) do
    ~H"""
    <div class={[
      "flex items-center justify-between py-2 px-3 bg-base-200 rounded-md",
      @class
    ]}>
      <div class="flex items-center space-x-3">
        <%= if Ecto.assoc_loaded?(@workflow_run.repository) do %>
          <.link
            href={
              github_job_url(
                @workflow_run.repository.owner,
                @workflow_run.repository.name,
                @workflow_run.github_id,
                @job.github_id
              )
            }
            target="_blank"
            class="github-link-inline"
          >
            <span class="text-sm font-medium text-base-content">{@job.name}</span>
            <.icon name="hero-arrow-top-right-on-square" class="h-3 w-3 text-base-content/60" />
          </.link>
        <% else %>
          <span class="text-sm font-medium text-base-content">{@job.name}</span>
        <% end %>
        <.status_badge status={@job.status} conclusion={@job.conclusion} class="text-xs" />
      </div>

      <div class="flex items-center space-x-4 text-xs text-base-content/60">
        <%= if @job.runner_name do %>
          <span class="flex items-center">
            <.icon name="hero-cpu-chip" class="mr-1 h-3 w-3 text-base-content/50" />
            {@job.runner_name}
          </span>
        <% end %>

        <.relative_time datetime={@job.started_at} />
        <%!-- <span>{time_ago(@job.started_at)}</span> --%>
      </div>
    </div>
    """
  end

  @doc """
  Renders a loading state indicator.

  ## Examples

      <.loading_state />
      <.loading_state message="Loading workflows..." />
  """
  attr :message, :string, default: "Loading...", doc: "loading message to display"
  attr :class, :string, default: "", doc: "additional CSS classes"

  def loading_state(assigns) do
    ~H"""
    <div class={["flex items-center justify-center py-12", @class]}>
      <div class="text-center">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
        <p class="mt-2 text-sm text-base-content/60">{@message}</p>
      </div>
    </div>
    """
  end

  @doc """
  Renders a connection status indicator.

  ## Examples

      <.connection_status connected={true} />
      <.connection_status connected={false} />
  """
  attr :connected, :boolean, default: true, doc: "whether the connection is active"
  attr :class, :string, default: "", doc: "additional CSS classes"

  def connection_status(assigns) do
    ~H"""
    <div class={["flex items-center space-x-2 text-xs", @class]}>
      <div class={[
        "w-2 h-2 rounded-full",
        if(@connected, do: "bg-success animate-pulse", else: "bg-error")
      ]}>
      </div>
      <span class="text-base-content/70">
        {if @connected, do: "Connected", else: "Disconnected"}
      </span>
    </div>
    """
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(CiRunnersWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(CiRunnersWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  @doc """
  Renders a copy button styled like a code block that can be clicked to copy text.

  ## Examples

      <.copy_button text="abc123def">
        abc123d
      </.copy_button>

      <.copy_button text={repository.commit_sha}>
        {String.slice(repository.commit_sha, 0, 8)}
      </.copy_button>

  """
  attr :text, :string, required: true, doc: "the text to copy to clipboard"
  attr :class, :string, default: "", doc: "additional CSS classes for the button"

  slot :inner_block, required: true, doc: "the visible content of the copy button"

  def copy_button(assigns) do
    assigns = assign_new(assigns, :class, fn -> "" end)

    ~H"""
    <button
      type="button"
      class={[
        "cursor-pointer",
        @class
      ]}
      phx-click={JS.dispatch("copy-to-clipboard")}
      data-value={@text}
    >
      {render_slot(@inner_block)}
    </button>
    <script :type={ColocatedJS}>
      window.addEventListener("copy-to-clipboard", (event) => {
        if ("clipboard" in navigator) {
          const text = event.target.dataset.value;
          navigator.clipboard.writeText(text);
          // TODO: Send a toast notification
        } else {
          alert("Sorry, your browser does not support clipboard copy.");
        }
      });
    </script>
    """
  end

  @doc """
  Renders relative time with automatic updates.

  ## Examples

      <.relative_time datetime={DateTime.utc_now()} />
      <.relative_time datetime={repository.started_at} class="text-sm text-gray-500" />

  """
  attr :datetime, :any, required: true, doc: "the datetime to display relatively"
  attr :class, :string, doc: "additional CSS classes for the time element"
  attr :id, :string, doc: "the optional id of the time element"

  def relative_time(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> nil end)
      |> assign_new(:id, fn -> "time-#{System.unique_integer([:positive])}" end)
      |> assign(:formatted_time, format_relative_time(assigns.datetime))
      |> assign(:js_timestamp, format_timestamp_for_js(assigns.datetime))

    ~H"""
    <span class={@class} id={@id} data-timestamp={@js_timestamp} phx-hook=".TimeAgo">
      {@formatted_time}
    </span>
    <script :type={ColocatedHook} name=".TimeAgo">
      export default {
        mounted() {
          this.updateTime();
          this.interval = setInterval(() => this.updateTime(), 1000);
        },

        updated() {
          this.updateTime();
        },

        destroyed() {
          if (this.interval) {
            clearInterval(this.interval);
          }
        },

        updateTime() {
          const el = this.el;
          const timestamp = el.dataset.timestamp;
          if (timestamp && timestamp !== "null" && timestamp !== "undefined") {
            try {
              const datetime = new Date(timestamp);
              if (!isNaN(datetime.getTime())) {
                const timeAgo = this.calculateTimeAgo(datetime);
                el.textContent = timeAgo;
              }
            } catch (error) {
              console.warn(
                "TimeAgo hook: Invalid timestamp format:",
                timestamp,
                error,
              );
            }
          }
        },

        calculateTimeAgo(datetime) {
          const now = new Date();
          const diffInSeconds = Math.floor((now - datetime) / 1000);

          // Handle future dates
          if (diffInSeconds < 0) {
            return "in the future";
          }

          // Handle "just now" case
          if (diffInSeconds < 5) {
            return "just now";
          }

          // Seconds (up to 59 seconds)
          if (diffInSeconds < 60) {
            return `${diffInSeconds}s ago`;
          }

          // Minutes (up to 59 minutes)
          const diffInMinutes = Math.floor(diffInSeconds / 60);
          if (diffInMinutes < 60) {
            return `${diffInMinutes}m ago`;
          }

          // Everything else is "a while ago"
          return Math.floor(diffInSeconds / 86400) + "d ago";
        },
      }
    </script>
    """
  end

  # UTILITIES

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  defp status_badge_class(status, conclusion) do
    case {status, conclusion} do
      {"completed", "success"} ->
        "bg-success/20 text-success-content border border-success/30"

      {"completed", "failure"} ->
        "bg-error/20 text-error-content border border-error/30"

      {"completed", "cancelled"} ->
        "bg-neutral/20 text-neutral-content border border-neutral/30"

      {"completed", "timed_out"} ->
        "bg-error/20 text-error-content border border-error/30"

      {"completed", "action_required"} ->
        "bg-warning/20 text-warning-content border border-warning/30"

      {"completed", "neutral"} ->
        "bg-info/20 text-info-content border border-info/30"

      {"completed", "skipped"} ->
        "bg-neutral/20 text-neutral-content border border-neutral/30"

      {"in_progress", _} ->
        "bg-info/20 text-info-content border border-info/30"

      {"queued", _} ->
        "bg-warning/20 text-warning-content border border-warning/30"

      {"waiting", _} ->
        "bg-warning/20 text-warning-content border border-warning/30"

      {"requested", _} ->
        "bg-neutral/20 text-neutral-content border border-neutral/30"

      _ ->
        "bg-neutral/20 text-neutral-content border border-neutral/30"
    end
  end

  defp status_badge_text(status, conclusion) do
    case {status, conclusion} do
      {"completed", "success"} -> "Success"
      {"completed", "failure"} -> "Failed"
      {"completed", "cancelled"} -> "Cancelled"
      {"completed", "timed_out"} -> "Timed Out"
      {"completed", "action_required"} -> "Action Required"
      {"completed", "neutral"} -> "Neutral"
      {"completed", "skipped"} -> "Skipped"
      {"completed", nil} -> "Completed"
      {"in_progress", _} -> "In Progress"
      {"queued", _} -> "Queued"
      {"waiting", _} -> "Waiting"
      {"requested", _} -> "Requested"
      _ -> String.capitalize(status || "Unknown")
    end
  end

  # GitHub URL helpers
  defp github_repo_url(owner, name), do: "https://github.com/#{owner}/#{name}"

  defp github_workflow_run_url(owner, name, run_github_id),
    do: "https://github.com/#{owner}/#{name}/actions/runs/#{run_github_id}"

  defp github_job_url(owner, name, run_github_id, job_github_id),
    do: "https://github.com/#{owner}/#{name}/actions/runs/#{run_github_id}/job/#{job_github_id}"

  defp github_branch_url(owner, name, branch),
    do: "#{github_repo_url(owner, name)}/tree/#{branch}"

  defp github_commit_url(owner, name, commit_sha),
    do: "#{github_repo_url(owner, name)}/commit/#{commit_sha}"

  # Dates
  defp format_relative_time(datetime) when is_nil(datetime), do: "—"

  defp format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      # Handle future dates
      diff < 0 -> "in the future"
      # Handle "just now" case
      diff < 5 -> "just now"
      # Seconds (up to 59 seconds)
      diff < 60 -> "#{diff}s ago"
      # Minutes (up to 59 minutes)
      diff < 3600 -> "#{div(diff, 60)}m ago"
      # Hours (up to 23 hours)
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      # Days
      true -> "#{div(diff, 86400)}d ago"
    end
  end

  defp format_timestamp_for_js(datetime) when is_nil(datetime), do: nil

  defp format_timestamp_for_js(datetime) do
    DateTime.to_iso8601(datetime)
  end
end
