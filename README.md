# godot-pub-sub
Publish-Subscribe mechanism for Godot/GDScript. Written using Godot 3.2, but should work with previous versions.

PubSub is a powerful programming pattern that allows decoupled components to subscribe to messages that interest them and receive notifications when those messages are published. See the [Publish-Subscribe Pattern](https://en.wikipedia.org/wiki/Publish%E2%80%93subscribe_pattern) Wikipedia page for more information.

## Example

A Player object in an RPG game can publish an event, `"player-xp-gained"`, whenever they gain XP. Other parts of the game can subscribe to the `player-xp-gained` event and respond accordingly. Monsters might increase their hit points, for example, or a UI component might trigger a particle effect on the XP indicator on screen.

The biggest benefit of publish-subscribe is that components can communicate without being directly aware of each other.

## Installation

1 Copy the **godot-pub-sub** folder to your projects addons folder

2 Choose **Project* menu -> **Project Settings** -> **Auto Load**

3 Add the `PubSub` class to the list

## PubSub class

The `PubSub` class is a static class, designed to be accessed from anywhere within a project without requiring `load()` or `preload()` calls.

## SubScribing to Events

Objects can subscribe to any number of event keys. Whenever one of them is published, the `event_published()` method is called (if there is one). The event key and payload supplied by the publishing code is passed in. Objects cannot return anything from `event_published()`, however see the section below on Instant Events.

## Publishing Events

Events are published by calling the `publish()` event and passing the event key and an optional payload. Event keys can be any type of data, include object references, but generally strings are used for readability. You can use constants to reduce errors, in which case numeric event keys could be used.

A handy way of passing information along with events is to use a dictionary as the event payload:

```Godot
var payload = {
	"item_description":"Glistening charm-shield of Methusala",
	"item_value":500
}
PubSub.publish("item_discovered", payload)
```

This code publishes the discovery of an item - objects subscribed to the event can obtain the item description and value by accessing the payload as a Dictionary.

## Instant Events

PubSub also includes a slightly different form of event publishing, called an "instant" event. When an instant event is published, all listeners are called and their response collated into an Array. This is then returned to the object which published the event. Instant events provide a way for objects to obtain information from other objects without having a reference to them; this can be useful when such a reference causea a circular reference.

## Asynchronous Events

PubSub usually publishes events to all listeners in one go when you call `publish()`. Another method, `publish_async()`, does not immediately call subscribers. Instead, it notes which subscribers need to be called and returns without calling them. Subscribers are subsequently called when the `PubSub.process()` method is called, one subscriber per call. You **must** call `PubSub.process()` somewhere in your main scene for this mechanism to work. It's up to you how often to call this method, however, so you can publish these asynchronous events every 1/10th of a second, for example.

## Methods

`subscribe(event_key, listener)`

Call the `subscribe()` method to subscribe the `listener` object to the given `event_key`. When the given event key is published, the `listener.event_published()` method will be called. If the method is not defined, nothing will happen.

Objects can subscribe to all events by passing an empty strong (`""`) in the `event_key` parameter. Be aware that if you're publishing a large number of events this object will receive many calls to its `event_published()` method, so make sure the code is fast!

`unsubscribe(listener, event_key = null)`

Unsubscribe `listener` from the given `event_key`, or all events if `event_key` is not supplied.

`publish(event_key, payload = null)`

Publishes an event to all listeners subscribed to `event_key`. The `event_published()` method of all listeners will be called (if they have one), with the `event_key` and optional `payload` parameter passed in. `payload` can be anything you need it to be - dictionaries are useful for passing a number of items of data.

`subscribe_instant(event_key, listener)`

Subscribes `listener` to an instant `event_key`.

`unsubscribe_instant(listener, event_key = null)`

Unsubscribes `listener` from the given instant `event_key`, or all instant events if not supplied.

`publish_instant(event_key, payload = null)`

Publishes an instant event with the given `event_key` and optional `payload`. The `instant_event_published()` method of all subscribers are called in turn and their responses returned in an array.

`process()`

If there are any asycnhronous events waiting to be published, removes the next one and publishes it. Only one event is processed by this method, which **must** be called regularly in your code somewhere for the asynchronous mechanism to work.

`clear()`

Removes all event subscriptions and registered services (see below).

`clear_instant_events()`

Removes all instant event subscriptions.

## Service Discovery

PubSub can also act as a Service Directory, allowing classes to find objects by an id number. 

`register_service(service_id:int, service)`

Registers a service with the given id number.

`get_service(service_id:int)`

Returns the service registered with the given service_id.

Say you need access to the monster spawner from within your TrappedChest class - once the spawner has registered itself just call PubSub to obtain it:

```Godot
extends Node
class_name TrappedChest

func open():
    var spawner = PubSub.get_service(MONSTER_SPAWNER)
    spawner.spawn_monster_near(self.location)
```

Your monster spawner class registers itself like this:

```Godot
func _init():
    PubSub.register_service(MONSTER_SPAWNER, self)
```


## Code Examples

The following example Player class publishes an event whenever XP is gained:

```Godot
extends Node
class_name Player

var xp:int = 100

func gain_xp(amount:int)->void:
	xp += amount
	PubSub.publish("player_xp_gained", amount)
```

This Monster class will be informed whenever the player gains XP:

```Godot
extends Node
class_name Monster

var hit_points:int = 80

func _init():
	PubSub.subscribe("player_xp_gained", self)

func queue_free():
	PubSub.unsubscribe(self)
	.queue_free()

func event_published(event_key, payload):
	if event_key=="player_xp_gained":
		hit_points += payload as int
```

Note how `Monster` unsubscribes itself from all messages in the `queue_free()` method - this is good practice and ensures that the object can be disposed without PubSub keeping a reference to it. PubSub will try and forget about objects which are queued to be freed up, but this should not be relied upon - if there's any chance that your object will be freed up at some point, unsubscribe from all PubSub events.

