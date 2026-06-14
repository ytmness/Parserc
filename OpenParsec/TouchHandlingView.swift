import ParsecSDK
import UIKit


class TouchController
{
	let viewController: UIViewController
	private var lastSelectionDragPoint: CGPoint = .zero

	init(viewController: UIViewController) {
		self.viewController = viewController
	}
	
	func onTouch(typeOfTap:Int, location:CGPoint, state:UIGestureRecognizer.State)
	{
		let x = Int32(location.x)
		let y = Int32(location.y)

		// Send the mouse input to the host
		let parsecTap = ParsecMouseButton(rawValue:UInt32(typeOfTap))
		switch state
		{
			case .began:
				CParsec.sendMouseMessage(parsecTap, x, y, true)
			case .changed:
				CParsec.sendMousePosition(x, y)
			case .ended, .cancelled:
				CParsec.sendMouseMessage(parsecTap, x, y, false)
			default:
				break
		}
	}

	func onTap(typeOfTap:Int, location:CGPoint)
	{
		let parsecTap = ParsecMouseButton(rawValue:UInt32(typeOfTap))
		if SettingsHandler.cursorMode == .direct {
			let x = Int32(location.x)
			let y = Int32(location.y)

			// Send the mouse input to the host
			// add release delay in case some games ignore instant key release
			CParsec.sendMouseMessage(parsecTap, x, y, true)
			DispatchQueue.global().asyncAfter(deadline: .now() + 0.02) {
				CParsec.sendMouseMessage(parsecTap, x, y, false)
			}

		} else {
			CParsec.sendMouseClickMessage(parsecTap, true)
			DispatchQueue.global().asyncAfter(deadline: .now() + 0.02) {
				CParsec.sendMouseClickMessage(parsecTap, false)
			}
		}

	}

	func onDoubleTap(typeOfTap: Int, location: CGPoint) {
		let parsecTap = ParsecMouseButton(rawValue: UInt32(typeOfTap))
		if SettingsHandler.cursorMode == .direct {
			let x = Int32(location.x)
			let y = Int32(location.y)
			CParsec.sendMouseMessage(parsecTap, x, y, true)
			DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
				CParsec.sendMouseMessage(parsecTap, x, y, false)
				DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
					CParsec.sendMouseMessage(parsecTap, x, y, true)
					DispatchQueue.global().asyncAfter(deadline: .now() + 0.02) {
						CParsec.sendMouseMessage(parsecTap, x, y, false)
					}
				}
			}
		} else {
			CParsec.sendMouseClickMessage(parsecTap, true)
			DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
				CParsec.sendMouseClickMessage(parsecTap, false)
				DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
					CParsec.sendMouseClickMessage(parsecTap, true)
					DispatchQueue.global().asyncAfter(deadline: .now() + 0.02) {
						CParsec.sendMouseClickMessage(parsecTap, false)
					}
				}
			}
		}
	}

	func onSelectionDrag(typeOfTap: Int, location: CGPoint, state: UIGestureRecognizer.State) {
		let parsecTap = ParsecMouseButton(rawValue: UInt32(typeOfTap))
		let x = Int32(location.x)
		let y = Int32(location.y)

		if SettingsHandler.cursorMode == .direct {
			switch state {
			case .began:
				CParsec.sendMouseMessage(parsecTap, x, y, true)
			case .changed:
				CParsec.sendMousePosition(x, y)
			case .ended, .cancelled:
				CParsec.sendMouseMessage(parsecTap, x, y, false)
			default:
				break
			}
		} else {
			switch state {
			case .began:
				lastSelectionDragPoint = location
				CParsec.sendMouseClickMessage(parsecTap, true)
			case .changed:
				CParsec.sendMouseDelta(
					Int32(Float(location.x - lastSelectionDragPoint.x) * SettingsHandler.mouseSensitivity),
					Int32(Float(location.y - lastSelectionDragPoint.y) * SettingsHandler.mouseSensitivity)
				)
				lastSelectionDragPoint = location
			case .ended, .cancelled:
				CParsec.sendMouseClickMessage(parsecTap, false)
			default:
				break
			}
		}
	}

	public func viewDidLoad()
	{


		
	}



	
}

/// Dos toques rápidos: el segundo mantiene pulsado y arrastra para seleccionar texto como un ratón.
class DoubleTapDragGestureRecognizer: UIGestureRecognizer {
	var isSelectionDragActive = false

	private var lastTouchUpTime: TimeInterval = 0
	private var lastTouchUpLocation: CGPoint = .zero
	private var waitingForSecondTap = false
	private var isSelectionDrag = false
	private var dragStartLocation: CGPoint = .zero
	private var firstTouchStartLocation: CGPoint = .zero
	private var firstTouchMoved = false
	private var activeTouch: UITouch?

	private let maxTapInterval: TimeInterval = 0.42
	private let maxTapDistance: CGFloat = 48

	var onSelectionDrag: ((UIGestureRecognizer.State, CGPoint) -> Void)?
	var onFirstTapClick: ((CGPoint) -> Void)?

	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let touch = touches.first, touches.count == 1 else {
			state = .failed
			return
		}
		if (event?.allTouches?.count ?? 0) > 1 {
			state = .failed
			return
		}

		activeTouch = touch
		let location = touch.location(in: view)
		let now = touch.timestamp

		if waitingForSecondTap,
		   now - lastTouchUpTime < maxTapInterval,
		   distance(from: location, to: lastTouchUpLocation) < maxTapDistance {
			waitingForSecondTap = false
			isSelectionDrag = true
			isSelectionDragActive = true
			dragStartLocation = location
			state = .began
			onSelectionDrag?(.began, location)
			return
		}

		waitingForSecondTap = false
		isSelectionDrag = false
		firstTouchStartLocation = location
		firstTouchMoved = false
		state = .possible
	}

	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let touch = activeTouch, touches.contains(touch), let view else { return }
		let location = touch.location(in: view)

		if isSelectionDrag {
			state = .changed
			onSelectionDrag?(.changed, location)
			return
		}

		if state == .possible && distance(from: location, to: firstTouchStartLocation) > 10 {
			firstTouchMoved = true
			waitingForSecondTap = false
			state = .failed
		}
	}

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let touch = activeTouch, touches.contains(touch), let view else { return }
		let location = touch.location(in: view)
		let now = touch.timestamp

		if isSelectionDrag {
			state = .ended
			onSelectionDrag?(.ended, location)
			isSelectionDrag = false
			isSelectionDragActive = false
			activeTouch = nil
			return
		}

		if firstTouchMoved {
			activeTouch = nil
			state = .failed
			return
		}

		onFirstTapClick?(location)
		lastTouchUpTime = now
		lastTouchUpLocation = location
		waitingForSecondTap = true
		activeTouch = nil
		state = .failed

		DispatchQueue.main.asyncAfter(deadline: .now() + maxTapInterval) { [weak self] in
			self?.waitingForSecondTap = false
		}
	}

	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		if isSelectionDrag {
			state = .cancelled
			onSelectionDrag?(.cancelled, lastTouchUpLocation)
			isSelectionDrag = false
			isSelectionDragActive = false
		}
		waitingForSecondTap = false
		activeTouch = nil
		state = .failed
	}

	override func reset() {
		super.reset()
		isSelectionDrag = false
		isSelectionDragActive = false
		activeTouch = nil
	}

	private func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
		hypot(a.x - b.x, a.y - b.y)
	}
}
