# Tapfall

A Ruby gem for ingesting ATProto repository data from a [Tap](https://github.com/bluesky-social/indigo/tree/main/cmd/tap) service (extension of the [Skyfall](https://tangled.org/mackuba.eu/skyfall) gem).

> [!NOTE]
> Part of ATProto Ruby SDK: [ruby.sdk.blue](https://ruby.sdk.blue)


## What does it do

[Tap](https://github.com/bluesky-social/indigo/tree/main/cmd/tap) is a [tool made by Bluesky](https://docs.bsky.app/blog/introducing-tap), which combines a firehose client/adapter with a JSON output like [Jetstream](https://github.com/bluesky-social/jetstream) and a repository/PDS crawler and importer. It can be useful if you're building some kind of backend app that needs to import and store some set of records from the Atmosphere. It's meant to be run locally on your app's server, with only your app connecting to it, and it simplifies a lot of code for you if you need to both import & backfill existing records of some kind and also stream any new ones that are added after you start the import.

Basically, before Tap, your app code needed to:

1) Connect to a relay or Jetstream
2) Filter only records of selected kinds
3) Find out which repos on which PDSes have records that are relevant to you
4) Connect to those PDSes and get those records via listRecords or getRepo
5) Handle possible duplicates between imported repo and the firehose

If you only want some kinds of records from some specific repos, that still leaves you with both a firehose client and a repo importer and merging the results from both somehow.

With Tap, you only need to:

1) Run Tap, passing it a list of record types to sync in command line parameters or in env
2) Connect to the Tap stream on localhost
3) Save everything coming from the stream

So instead of two ways of importing the records, you only have one and it's the much less involved one. And this library also handles a lot of this for you.

**Tapfall** is an extension of [Skyfall](https://tangled.org/mackuba.eu/skyfall), which is a gem for streaming records from a relay/PDS firehose or Jetstream, and it adds support for the event format used by Tap and for some additional HTTP APIs it provides.


## Installation

Add this to your `Gemfile`:

    gem 'tapfall', '~> 0.1'


## Usage

Create a `Tapfall::Stream` object, specifying the address of the Tap service websocket:

```rb
require 'tapfall'

tap = Tapfall::Stream.new('ws://localhost:2480')
```

You can also just pass a hostname, but then it's interpreted as HTTPS/WSS, which might not be what you want.

Next, set up event listeners to handle incoming messages and get notified of errors. Here are all the available listeners (you will need at least `on_message`):

```rb
# this gives you a parsed message object, one of subclasses of Tapfall::TapMessage
tap.on_message { |msg| p msg }

# lifecycle events
tap.on_connecting { |url| puts "Connecting to #{url}..." }
tap.on_connect { puts "Connected" }
tap.on_disconnect { puts "Disconnected" }
tap.on_reconnect { puts "Connection lost, trying to reconnect..." }
tap.on_timeout { puts "Connection stalled, triggering a reconnect..." }

# handling errors (there's a default error handler that does exactly this)
tap.on_error { |e| puts "ERROR: #{e}" }
```

You can also call these as setters accepting a `Proc` – e.g. to disable default error handling, you can do:

```rb
tap.on_error = nil
```

When you're ready, open the connection by calling `connect`:

```rb
tap.connect
```

The `#connect` method blocks until the connection is explicitly closed with `#disconnect` from an event or interrupt handler. Tapfall & Skyfall use [EventMachine](https://github.com/eventmachine/eventmachine) under the hood, so in order to run some things in parallel, you can use e.g. `EM::PeriodicTimer`.

Tapfall also supports Skyfall's `on_raw_message` handler version, but only if you use Tap in "disable acks" mode (see below), which is not recommended beyond testing, unless you're doing the acks yourself. (This is because Tapfall needs to parse the message into a JSON form in order to get the `id` of the event to send the "ack".)

> [!NOTE]
> Unlike standard firehose and Jetstream, Tap streams don't have a cursor that you store and pass when reconnecting. It's meant to be used only by one client, and it tracks internally itself which events have been sent to you and which weren't. You can think about it this way: it's not a public service like Jetstream that you can share with others, it's a microservice that you run as a component of your app.


### Acks

Tap by default runs in a mode where it expects the client to send back an "ack" after receiving and processing each event. When it gets the ack, it marks the event as processed and will not send it again. If you don't send an ack, it tries to retransmit the event after a moment.

You can also run it with acks disabled, by passing a `--disable-acks` option or `TAP_DISABLE_ACKS=true` env var, in which case it will assume an event has been processed as soon as it's sent to you. This is not recommended to do in production, since if your process crashes during an event processing loop, that event will be lost (and you can't ask for an earlier cursor because there's no cursor).

Tapfall handles the acks for you automatically. If you want it to not send acks, pass an `:ack => false` option to the constructor:

```rb
tap = Tapfall::Stream.new(server, { ack: false })
```

### Password-protected access

Tap also lets you set an admin password, which you can set with the `--admin-password` option or `TAP_ADMIN_PASSWORD` env var. This locks the stream and the API behind HTTP Basic auth (with the user `admin`). Pass the password to Tapfall constructor like this:

```rb
tap = Tapfall::Stream.new(server { admin_password: 'abracadabra' })
```

### Processing messages

Each message passed to `on_message` is an instance of a subclass of `Tapfall::TapMessage`. The main event type is `Tapfall::RecordMessage`, which includes a record operation; you will also receive `Tapfall::IdentityMessage` events, which provide info about an account change like changed handle or migration to a new PDS. `UnknownMessage` might be sent if new unrecognized message types are sent in the future.

All message types share these properties:

- `type` (symbol) – the message type identifier, e.g. `:record`
- `id` (integer), aliased as `seq` – a sequential index of the message

The `:record` messages have an `operations` method, which includes an array of add/remove/edit `Operation`s done on some records. Currently Tap event format only includes one single record operation in each event, but it's returned as an array here for symmetry with the `Skyfall::Firehose` stream version.

An `Operation` has such fields (also matching the API of `Skyfall::Firehose::Operation` and `Skyfall::Jetstream::Operation`):

- `repo` or `did` (string) – DID of the repository (user account)
- `collection` (string) – name of the collection / record type, e.g. `app.bsky.feed.post` for posts
- `type` (symbol) – short name of the collection, e.g. `:bsky_post`
- `rkey` (string) – identifier of a record in a collection
- `path` (string) – the path part of the at:// URI – collection name + ID (rkey) of the item
- `uri` (string) – the complete at:// URI
- `action` (symbol) – `:create`, `:update` or `:delete`
- `cid` (CID) – CID of the operation/record (`nil` for delete operations)
- `live?` (boolean) – true if the record was received from the firehose, false if it was backfilled from the repo

Create and update operations will also have an attached record (JSON object) with details of the post, like etc. The record data is currently available as a Ruby hash via `raw_record` property (custom types may be added in future).

So for example, in order to filter only "create post" operations and print their details, you can do something like this:

```rb
tap.on_message do |m|
  next if m.type != :record

  m.operations.each do |op|
    next unless op.action == :create && op.type == :bsky_post

    puts "#{op.repo}:"
    puts op.raw_record['text']
    puts
  end
end
```


### Note on custom lexicons

Note that the `Operation` objects have two properties that tell you the kind of record they're about: `#collection`, which is a string containing the official name of the collection/lexicon, e.g. `"app.bsky.feed.post"`; and `#type`, which is a symbol meant to save you some typing, e.g. `:bsky_post`.

When Tapfall receives a message about a record type that's not on the list, whether in the `app.bsky` namespace or not, the operation `type` will be `:unknown`, while the `collection` will be the original string. So if an app like e.g. "Skygram" appears with a `zz.skygram.*` namespace that lets you share photos on ATProto, the operations will have a type `:unknown` and collection names like `zz.skygram.feed.photo`, and you can check the `collection` field for record types known to you and process them in some appropriate way, even if Tapfall doesn't recognize the record type.

Do not however check if such operations have a `type` equal to `:unknown` first – just ignore the type and only check the `collection` string. The reason is that some next version might start recognizing those records and add a new `type` value for them like e.g. `:skygram_photo`, and then they won't match your condition anymore.


### Reconnection logic

See the section in the [Skyfall readme](https://tangled.org/mackuba.eu/skyfall#reconnection-logic) about the options for handling reconnecting to a flaky firehose – but since in this case the Tap service will run under your control, likely on the same machine, this might not be as useful in practice.


## HTTP API

Apart from the `/channel` websocket endpoint, Tap also has [a few other endpoints](https://github.com/bluesky-social/indigo/tree/main/cmd/tap#http-api) for adding/removing repos and checking various stats.

You can call all the below methods either on the `Tapfall::Stream` instance you use for connecting to the websocket, or on a separate `Tapfall::API` object if you prefer.

Currently implemented endpoints:

### /repos/add

Tap can work in three possible ways regarding the subset of repos it tracks:

1) `TAP_FULL_NETWORK`, when it tracks *all repos everywhere*
2) `TAP_SIGNAL_COLLECTION`, when it finds and tracks all repos that have some specific types of records you're interested in
3) default mode, when it only tracks repos you've added manually

In that third mode, use this to add repos to the tracking list:

```rb
@tap.add_repo('did:plc:uh4errluyq5thgszrwwrtpuq')

# or:
@tap.add_repos(did_list)
```

### /repos/remove

To remove repos from the list, use:

```rb
@tap.remove_repo('did:plc:uh4errluyq5thgszrwwrtpuq')

# or:
@tap.remove_repos(did_list)
```


## Credits

Copyright © 2025 Kuba Suder ([@mackuba.eu](https://bsky.app/profile/did:plc:oio4hkxaop4ao4wz2pp3f4cr)).

The code is available under the terms of the [zlib license](https://choosealicense.com/licenses/zlib/) (permissive, similar to MIT).

Bug reports and pull requests are welcome 😎
