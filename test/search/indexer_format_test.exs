# SPDX-License-Identifier: AGPL-3.0-only

defmodule CommonsPub.Search.IndexerFormatTest do
  use CommonsPub.DataCase
  alias CommonsPub.Search.Indexer
  import CommonsPub.Utils.Simulation

  test "format community" do
    community = fake_user!() |> fake_community!()
    json = Indexer.maybe_indexable_object(community)
    assert json["id"] == community.id
    assert json["canonical_url"] == CommonsPub.ActivityPub.Utils.get_actor_canonical_url(community)
    # assert json["icon"] == community.icon
    # assert json["image"] == community.image
    assert json["username"] == "&"<>community.character.preferred_username
    assert json["summary"] == community.summary
    assert json["index_type"] == "Community"
  end

  test "format collection" do
    user = fake_user!()
    community = fake_community!(user)
    collection = fake_collection!(user, community)

    json = Indexer.maybe_indexable_object(collection)
    assert json["id"] == collection.id
    assert json["canonical_url"] == collection.character.canonical_url
    # assert json["icon"] == collection.icon
    assert json["username"] == "+"<>collection.character.preferred_username
    assert json["summary"] == collection.summary
    assert json["index_type"] == "Collection"
    assert is_map(json["context"])
  end

  test "format resource" do
    user = fake_user!()
    community = fake_community!(user)
    collection = fake_collection!(user, community)
    resource = fake_resource!(user, collection)

    json = Indexer.maybe_indexable_object(resource)
    assert String.starts_with?(json["url"], "http")
    assert json["id"] == resource.id
    assert json["canonical_url"] == resource.canonical_url
    # assert json["icon"] == resource.icon
    assert json["summary"] == resource.summary
    assert json["index_type"] == "Resource"
    assert is_map(json["context"])
    # assert is_map(json["context"]["context"])
    assert is_binary(json["licence"])
  end
end
