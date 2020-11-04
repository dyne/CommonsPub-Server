# ZenPub Federated Server

[![software by Dyne.org](https://files.dyne.org/software_by_dyne.png)](http://www.dyne.org)

## About the project

ZenPub is the core software component of [ReflowOS](https://reflowos.dyne.org) the open source hub to operate [circular economy](https://en.wikipedia.org/wiki/Circular_economy) networks and manage material flows in a city according to the [Valueflows](https://valueflo.ws) ontology.

ZenPub is a flavour of the [CommonsPub](http://commonspub.org) software implementing [ActivityPub](http://activitypub.rocks/) and `ActivityStreams` web standards.

This is the main repository, written in Elixir (running on Erlang/OTP), it is configured to use [PostgreSQL](https://www.postgresql.org/) as storage database.

The API offers access via [GraphQL](https://graphql.org/).

---

## Documentation

Do you want to...

- Understand the goals and use-cases of this projet? Read our [manual](https://reflowos.dyne.org).

- Read about the CommonsPub architecture? Read our [overview](./docs/ARCHITECTURE.md).

- Hack on the code? Read our [Developer FAQs](./docs/HACKING.md).

- Understand the client API? Read our [GraphQL guide](./docs/GRAPHQL.md).

- Deploy in production? Read our [Deployment Docs](./docs/DEPLOY.md).

---

## Extensions

Features are being developed in seperate namespaces in order to make the software more modular (to then be spun out into individual libraries):

- `lib/extensions/value_flows` - implementation of the [ValueFlows](https://valueflo.ws/) economic taxonomy
- `lib/activity_pub_adapter` - integration with a library that provides [ActivityPub](http://activitypub.rocks/) federation protocol.
- `lib/extensions/organisations` - Adds functionality for organisations to maintain a shared profile.
- `lib/extensions/tags` - For tagging, @ mentions, and user-maintained taxonomies of categories.
- `lib/extensions/measurements` - Various units and measures for indicating amounts (incl duration).
- `lib/extensions/locales` - Extensive schema of languages/countries/etc. The data is also open and shall be made available oustide the repo.
- `lib/extensions/geolocations` - Shared 'spatial things' database for tagging objects with a location.

## Licensing

ZenPub is licensed under the GNU Affero GPL version 3.0 (GNU AGPLv3).

Copyright © 2017-2020 by all contributors.

This repository includes code from:

- [CommonsPub](https://commonspub.org), copyright (c) 2018-2020, CommonsPub Contributors
- [REFLOW project](https://reflowproject.eu), copyright (c) 2020 Dyne.org foundation
- [HAHA Academy](https://haha.academy/), copyright (c) 2020, Mittetulundusühing HAHA Academy
- [MoodleNet](http://moodle.net), copyright (c) 2018-2020 Moodle Pty Ltd
- [Pleroma](https://pleroma.social), copyright (c) 2017-2020, Pleroma Authors

For a list of linked libraries, including their origin and licenses, see [docs/DEPENDENCIES.md](./docs/DEPENDENCIES.md)
