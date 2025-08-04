defmodule CiRunners.Repositories do
  @moduledoc """
  Context module for managing repositories.

  Provides functions for creating, updating, and retrieving repository records
  based on GitHub webhook data.
  """

  alias CiRunners.Repo
  alias CiRunners.Github.Repository

  @doc """
  Creates or updates a repository based on GitHub webhook data.

  ## Parameters
  - repository_data: Map containing GitHub repository information

  ## Returns
  - {:ok, %Repository{}} on success
  - {:error, reason} on failure

  ## Examples
      iex> CiRunners.Repositories.upsert_from_webhook(%{
      ...>   "id" => 123456,
      ...>   "name" => "my-repo",
      ...>   "owner" => %{"login" => "username"}
      ...> })
      {:ok, %Repository{}}
  """
  def upsert_from_webhook(%{"id" => github_id, "owner" => %{"login" => owner}, "name" => name}) do
    attrs = %{
      github_id: github_id,
      owner: owner,
      name: name
    }

    case get_by_github_id(github_id) do
      nil ->
        create_repository(attrs)

      existing_repo ->
        update_repository(existing_repo, attrs)
    end
  end

  def upsert_from_webhook(nil) do
    {:error, :missing_repository_data}
  end

  def upsert_from_webhook(_repository_data) do
    {:error, :invalid_repository_data}
  end

  @doc """
  Gets a repository by its GitHub ID.

  ## Parameters
  - github_id: The GitHub ID of the repository

  ## Returns
  - %Repository{} if found
  - nil if not found
  """
  def get_by_github_id(github_id) do
    Repo.get_by(Repository, github_id: github_id)
  end

  @doc """
  Creates a new repository.

  ## Parameters
  - attrs: Map of repository attributes

  ## Returns
  - {:ok, %Repository{}} on success
  - {:error, %Ecto.Changeset{}} on failure
  """
  def create_repository(attrs) do
    %Repository{}
    |> Repository.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing repository.

  ## Parameters
  - repository: The repository struct to update
  - attrs: Map of updated attributes

  ## Returns
  - {:ok, %Repository{}} on success
  - {:error, %Ecto.Changeset{}} on failure
  """
  def update_repository(%Repository{} = repository, attrs) do
    repository
    |> Repository.changeset(attrs)
    |> Repo.update()
  end
end
