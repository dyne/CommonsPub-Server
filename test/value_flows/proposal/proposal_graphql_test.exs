defmodule ValueFlows.Proposal.GraphQLTest do
  use CommonsPub.Web.ConnCase, async: true

  import CommonsPub.Utils.Trendy, only: [some: 2]
  import CommonsPub.Utils.Simulation
  import CommonsPub.Test.Faking

  import Geolocation.Simulate

  import ValueFlows.Simulate
  import ValueFlows.Test.Faking

  @debug false
  @schema CommonsPub.Web.GraphQL.Schema

  describe "proposal" do
    test "fetches a proposal by ID (via GraphQL HTTP)" do
      user = fake_user!()
      proposal = fake_proposal!(user)

      q = proposal_query()
      # IO.inspect(q)

      conn = user_conn(user)

      assert proposal_queried =
               grumble_post_key(q, conn, :proposal, %{id: proposal.id}, "test", false)

      assert_proposal_full(proposal_queried)
    end

    test "fetches a full nested proposal by ID (via Absinthe.run)" do
      user = fake_user!()
      parent = fake_user!()
      location = fake_geolocation!(user)
      proposal = fake_proposal!(user, %{
        in_scope_of: [parent.id],
        eligible_location_id: location.id
      })
      intent = fake_intent!(user)

      some(5, fn ->
        fake_proposed_intent!(proposal, intent)
      end)

      some(5, fn ->
        fake_proposed_to!(fake_agent!(), proposal)
      end)

      assert proposal_queried =
               CommonsPub.Web.GraphQL.QueryHelper.run_query_id(
                 proposal.id,
                 @schema,
                 :proposal,
                 4,
                 nil,
                 @debug
               )

      assert_proposal_full(proposal_queried)
    end
  end

  describe "proposal.publishes" do
    test "fetches all proposed intents for a proposal" do
      user = fake_user!()
      proposal = fake_proposal!(user)
      intent = fake_intent!(user)

      some(5, fn ->
        fake_proposed_intent!(proposal, intent)
      end)

      q = proposal_query(fields: [publishes: [:id]])
      conn = user_conn(user)
      assert proposal = grumble_post_key(q, conn, :proposal, %{id: proposal.id})
      assert Enum.count(proposal["publishes"]) == 5
    end
  end

  describe "proposal.publishes.publishedIn" do
    test "lists the proposals for a proposed intent" do
      user = fake_user!()
      proposal = fake_proposal!(user)
      intent = fake_intent!(user)

      some(5, fn -> fake_proposed_intent!(proposal, intent) end)

      q =
        proposal_query(
          fields: [
            publishes: [:id, published_in: proposal_fields()]
          ]
        )

      conn = user_conn(user)
      assert fetched = grumble_post_key(q, conn, :proposal, %{id: proposal.id})
      assert_proposal(proposal, fetched)
    end
  end

  describe "proposal.publishedTo" do
    test "fetches all proposed to items for a proposal" do
      user = fake_user!()
      proposal = fake_proposal!(user)

      some(5, fn ->
        fake_proposed_to!(fake_agent!(), proposal)
      end)

      q = proposal_query(fields: [published_to: [:id]])
      conn = user_conn(user)
      assert proposal = grumble_post_key(q, conn, :proposal, %{id: proposal.id})
      assert Enum.count(proposal["publishedTo"]) == 5
    end
  end

  describe "proposal.eligibleLocation" do
    test "fetches an associated eligible location" do
      user = fake_user!()
      location = fake_geolocation!(user)
      proposal = fake_proposal!(user, %{eligible_location_id: location.id})

      q = proposal_query(fields: [eligible_location: [:id]])
      conn = user_conn(user)
      assert proposal = grumble_post_key(q, conn, :proposal, %{id: proposal.id})
      assert proposal["eligibleLocation"]["id"] == location.id
    end
  end

  describe "proposal.inScopeOf" do
    test "returns the scope of the proposal" do
      user = fake_user!()
      parent = fake_user!()
      proposal = fake_proposal!(user, %{in_scope_of: [parent.id]})

      q = proposal_query(fields: [in_scope_of: [:__typename]])
      conn = user_conn(user)
      assert proposal = grumble_post_key(q, conn, :proposal, %{id: proposal.id})
      assert hd(proposal["inScopeOf"])["__typename"] == "Person"
    end
  end

  describe "proposalPages" do
    test "fetches a page of proposals" do
      user = fake_user!()
      proposals = some(5, fn -> fake_proposal!(user) end)
      after_proposal = List.first(proposals)

      q = proposals_pages_query()
      conn = user_conn(user)
      vars = %{after: after_proposal.id, limit: 2}
      assert %{"edges" => fetched} = grumble_post_key(q, conn, :proposalsPages, vars)
      assert Enum.count(fetched) == 2
      assert List.first(fetched)["id"] == after_proposal.id
    end
  end

  describe "createProposal" do
    test "creates a new proposal" do
      user = fake_user!()
      q = create_proposal_mutation()
      conn = user_conn(user)
      vars = %{proposal: proposal_input()}
      assert proposal = grumble_post_key(q, conn, :create_proposal, vars)["proposal"]
      assert_proposal_full(proposal)
    end

    test "creates a new proposal with a scope" do
      user = fake_user!()
      parent = fake_user!()

      q = create_proposal_mutation(fields: [in_scope_of: [:__typename]])
      conn = user_conn(user)
      vars = %{proposal: proposal_input(%{"inScopeOf" => [parent.id]})}
      assert proposal = grumble_post_key(q, conn, :create_proposal, vars)["proposal"]
      assert_proposal_full(proposal)
      assert hd(proposal["inScopeOf"])["__typename"] == "Person"
    end

    test "creates a new proposal with an eligible location" do
      user = fake_user!()
      location = fake_geolocation!(user)

      q = create_proposal_mutation(fields: [eligible_location: [:id]])
      conn = user_conn(user)
      vars = %{proposal: proposal_input(%{"eligibleLocation" => location.id})}
      assert proposal = grumble_post_key(q, conn, :create_proposal, vars)["proposal"]
      assert proposal["eligibleLocation"]["id"] == location.id
    end
  end

  describe "updateProposal" do
    test "updates an existing proposal" do
      user = fake_user!()
      proposal = fake_proposal!(user)

      q = update_proposal_mutation()
      conn = user_conn(user)
      vars = %{proposal: update_proposal_input(%{"id" => proposal.id})}
      assert proposal = grumble_post_key(q, conn, :update_proposal, vars)["proposal"]
      assert_proposal_full(proposal)
    end

    test "updates an existing proposal with a new scope" do
      user = fake_user!()
      scope = fake_community!(user)
      proposal = fake_proposal!(user, %{in_scope_of: [scope.id]})

      new_scope = fake_community!(user)
      q = update_proposal_mutation()
      conn = user_conn(user)

      vars = %{
        proposal: update_proposal_input(%{"id" => proposal.id, "inScopeOf" => [new_scope.id]})
      }

      assert proposal = grumble_post_key(q, conn, :update_proposal, vars)["proposal"]
      assert_proposal_full(proposal)
    end
  end

  describe "deleteProposal" do
    test "deletes an existing proposal" do
      user = fake_user!()
      proposal = fake_proposal!(user)

      q = delete_proposal_mutation()
      conn = user_conn(user)
      assert grumble_post_key(q, conn, :delete_proposal, %{"id" => proposal.id})
    end
  end
end
