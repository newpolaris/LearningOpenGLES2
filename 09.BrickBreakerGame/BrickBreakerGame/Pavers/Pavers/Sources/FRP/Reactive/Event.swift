//
//  Event.swift
//  ReactiveSwift
//
//  Created by Justin Spahr-Summers on 2015-01-16.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

extension Signal {
	/// Represents a signal event.
	///
	/// Signals must conform to the grammar:
	/// `value* (failed | completed | interrupted)?`
	public enum Event {
		/// A value provided by the signal.
		case value(Value)

		/// The signal terminated because of an error. No further events will be
		/// received.
		case failed(Error)

		/// The signal successfully terminated. No further events will be received.
		case completed

		/// Event production on the signal has been interrupted. No further events
		/// will be received.
		///
		/// - important: This event does not signify the successful or failed
		///              completion of the signal.
		case interrupted

		/// Whether this event is a completed event.
		public var isCompleted: Bool {
			switch self {
			case .completed:
				return true

			case .value, .failed, .interrupted:
				return false
			}
		}

		/// Whether this event indicates signal termination (i.e., that no further
		/// events will be received).
		public var isTerminating: Bool {
			switch self {
			case .value:
				return false

			case .failed, .completed, .interrupted:
				return true
			}
		}

		/// Lift the given closure over the event's value.
		///
		/// - important: The closure is called only on `value` type events.
		///
		/// - parameters:
		///   - f: A closure that accepts a value and returns a new value
		///
		/// - returns: An event with function applied to a value in case `self` is a
		///            `value` type of event.
		public func map<U>(_ f: (Value) -> U) -> Signal<U, Error>.Event {
			switch self {
			case let .value(value):
				return .value(f(value))

			case let .failed(error):
				return .failed(error)

			case .completed:
				return .completed

			case .interrupted:
				return .interrupted
			}
		}

		/// Lift the given closure over the event's error.
		///
		/// - important: The closure is called only on failed type event.
		///
		/// - parameters:
		///   - f: A closure that accepts an error object and returns
		///        a new error object
		///
		/// - returns: An event with function applied to an error object in case
		///            `self` is a `.Failed` type of event.
		public func mapError<F>(_ f: (Error) -> F) -> Signal<Value, F>.Event {
			switch self {
			case let .value(value):
				return .value(value)

			case let .failed(error):
				return .failed(f(error))

			case .completed:
				return .completed

			case .interrupted:
				return .interrupted
			}
		}

		/// Unwrap the contained `value` value.
		public var value: Value? {
			if case let .value(value) = self {
				return value
			} else {
				return nil
			}
		}

		/// Unwrap the contained `Error` value.
		public var error: Error? {
			if case let .failed(error) = self {
				return error
			} else {
				return nil
			}
		}
	}
}

extension Signal.Event where Value: Equatable, Error: Equatable {
	public static func == (lhs: Signal<Value, Error>.Event, rhs: Signal<Value, Error>.Event) -> Bool {
		switch (lhs, rhs) {
		case let (.value(left), .value(right)):
			return left == right

		case let (.failed(left), .failed(right)):
			return left == right

		case (.completed, .completed):
			return true

		case (.interrupted, .interrupted):
			return true

		default:
			return false
		}
	}
}

extension Signal.Event: CustomStringConvertible {
	public var description: String {
		switch self {
		case let .value(value):
			return "VALUE \(value)"

		case let .failed(error):
			return "FAILED \(error)"

		case .completed:
			return "COMPLETED"

		case .interrupted:
			return "INTERRUPTED"
		}
	}
}

/// Event protocol for constraining signal extensions
public protocol EventProtocol {
	/// The value type of an event.
	associatedtype Value
	/// The error type of an event. If errors aren't possible then `NoError` can
	/// be used.
	associatedtype Error: Swift.Error
	/// Extracts the event from the receiver.
	var event: Signal<Value, Error>.Event { get }
}

extension Signal.Event: EventProtocol {
	public var event: Signal<Value, Error>.Event {
		return self
	}
}

extension Signal.Event {
	internal static func filter(_ isIncluded: @escaping (Value) -> Bool) -> (@escaping Signal<Value, Error>.Observer.Action) -> (Signal<Value, Error>.Event) -> Void {
		return { action in
			return { event in
				switch event {
				case let .value(value):
					if isIncluded(value) {
						action(.value(value))
					}

				case .completed:
					action(.completed)

				case let .failed(error):
					action(.failed(error))

				case .interrupted:
					action(.interrupted)
				}
			}
		}
	}

	internal static func filterMap<U>(_ transform: @escaping (Value) -> U?) -> (@escaping Signal<U, Error>.Observer.Action) -> (Signal<Value, Error>.Event) -> Void {
		return { action in
			return { event in
				switch event {
				case let .value(value):
					if let newValue = transform(value) {
						action(.value(newValue))
					}

				case .completed:
					action(.completed)

				case let .failed(error):
					action(.failed(error))

				case .interrupted:
					action(.interrupted)
				}
			}
		}
	}

	internal static func map<U>(_ transform: @escaping (Value) -> U) -> (@escaping Signal<U, Error>.Observer.Action) -> (Signal<Value, Error>.Event) -> Void {
		return { action in
			return { event in
				switch event {
				case let .value(value):
					action(.value(transform(value)))

				case .completed:
					action(.completed)

				case let .failed(error):
					action(.failed(error))

				case .interrupted:
					action(.interrupted)
				}
			}
		}
	}

	internal static func mapError<E>(_ transform: @escaping (Error) -> E) -> (@escaping Signal<Value, E>.Observer.Action) -> (Signal<Value, Error>.Event) -> Void {
		return { action in
			return { event in
				switch event {
				case let .value(value):
					action(.value(value))

				case .completed:
					action(.completed)

				case let .failed(error):
					action(.failed(transform(error)))

				case .interrupted:
					action(.interrupted)
				}
			}
		}
	}
}
