"""
Publish-Subscribe mechanism
"""
extends Node
class_name PubSub

const subscriptions = {}

const instant_subscriptions = {}

const published_async = []

const all_events = []

static func subscribe(event_key, listener)->void:
	"""
	Subscribes listener to the given event_key.
	"""
	if !listener.has_method("event_published"):
		# No method to call
		return
	if event_key=="":
		# Subscribe to all events
		all_events.append(listener)
	elif subscriptions.has(event_key):
		if !subscriptions[event_key].has(listener):
			subscriptions[event_key].append(listener)
	else:
		subscriptions[event_key] = [listener]

static func unsubscribe(listener, event_key = null)->void:
	"""
	Unsubscribes listener from event_key, or all event_keys if not supplied
	"""
	if event_key==null:
		for arr in subscriptions.values():
			if arr.has(listener): arr.erase(listener)
		if all_events.has(listener):
			all_events.erase(listener)
	else:
		subscriptions[event_key].erase(listener)

static func publish(event_key, payload = null)->void:
	"""
	Publishes the given event_key and payload. Subscribers to event_key will 
	have their eventPublished methods called.
	"""
	if !subscriptions.has(event_key): return
	var listeners = subscriptions[event_key] as Array
	var toRemove = []
	for listener in listeners:
		if listener.is_queued_for_deletion():
			toRemove.add(listener)
		else:
			listener.event_published(event_key, payload)
	# Tidy up any deleted listener objects
	for listenerToRemove in toRemove:
		listeners.erase(listenerToRemove)

static func publish_to_random(event_key:String, payload)->void:
	"""
	Publish an event to a single randomly-chosen subscriber
	"""
	if !subscriptions.has(event_key): return
	var listeners = subscriptions[event_key]
	var index = rand_range(0, listeners.length-1)
	listeners[index].eventPublished(event_key, payload)


static func publish_async(event_key, payload)->void:
	"""
	Queue the given event for async publishing. PubSub._process() MUST be called for this to work!
	"""
	if !subscriptions.has(event_key): return
	var listeners = subscriptions[event_key]
	var toRemove = []
	for listener in listeners:
		if listener.is_queued_for_deletion():
			toRemove.add(listener)
		elif listener.has_method("event_published"):
			published_async.push_front([listener, event_key, payload])
	# Tidy up any deleted listener objects
	for listenerToRemove in toRemove:
		listeners.erase(listenerToRemove)
	
static func subscribe_instant(event_key, listener)->void:
	"""
	Subscribes listener to the given instant event_key.
	"""
	if instant_subscriptions.has(event_key):
		if !instant_subscriptions[event_key].has(listener):
			instant_subscriptions[event_key].append(listener)
	else:
		instant_subscriptions[event_key] = [listener]

static func unsubscribe_instant(listener, event_key = null)->void:
	"""
	Unsubscribes listener from instant event_key, or all event_keys if not supplied
	"""
	if event_key==null:
		for arr in instant_subscriptions.values():
			if arr.has(listener): arr.erase(listener)
	else:
		instant_subscriptions[event_key].erase(listener)


static func publish_instant(event_key, payload)->Array:
	"""
	Publish the given instant event key to all listeners and return an array of their responses
	"""
	var result = []
	if !subscriptions.has(event_key): return result
	var listeners = subscriptions[event_key] as Array
	for listener in listeners:
		result.append(listener.instantEventPublished(event_key, payload))
	return result


static func process()->void:
	"""
	Process the next outstanding async event, if any.
	"""
	if published_async.size()==0: return

	var arr = published_async.pop_back() as Array
	var listener = arr[0]
	var event_key = arr[1]
	var payload = arr[2]
	if listener.has_method("event_published"):
		listener.event_published(event_key, payload)

static func clear()->void:
	"""
	Clears all event subscriptions
	"""
	subscriptions.clear()

static func clear_instant_events()->void:
	"""
	Clears all instant event subscriptions
	"""
	instant_subscriptions.clear()
