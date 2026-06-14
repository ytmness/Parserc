//
//  PoinerRegion.swift
//  OpenParsec
//
//  Created by s s on 2024/5/11.
//

import Foundation
import UIKit
import ParsecSDK


protocol ParsecPlayground {
	init(viewController: UIViewController, updateImage: @escaping () -> Void)
	func viewDidLoad()
	func cleanUp()
	func updateSize(width: CGFloat, height: CGFloat)
}


class ParsecViewController :UIViewController {
	var glkView: ParsecPlayground!
	var gamePadController: GamepadController!
	var touchController: TouchController!
	var u:UIImageView?
	var lastImg: CGImage?
	
	var lastLongPressPoint : CGPoint = CGPoint()
	
	var keyboardAccessoriesView : UIView?
	var keyboardHeight : CGFloat = 0.0
	var clipboardQuickBar : UIVisualEffectView?

	private var panGestureRecognizer: UIPanGestureRecognizer!
	private var singleFingerTapGestureRecognizer: UITapGestureRecognizer!
	private var doubleTapDragGestureRecognizer: DoubleTapDragGestureRecognizer!
	private var lastDirectDragPoint: CGPoint = .zero
	private var directDragActive = false
	
	override var prefersPointerLocked: Bool {
		return true
	}
	
	override var prefersHomeIndicatorAutoHidden : Bool {
		return true
	}
	
	init() {
		super.init(nibName: nil, bundle: nil)
		
		self.glkView = ParsecGLKViewController(viewController: self, updateImage: updateImage)
		
		self.gamePadController = GamepadController(viewController: self)
		self.touchController = TouchController(viewController: self)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func updateImage() {
		if CParsec.mouseInfo.cursorImg != nil && !CParsec.mouseInfo.cursorHidden {
			if lastImg != CParsec.mouseInfo.cursorImg{
				u!.image = UIImage(cgImage: CParsec.mouseInfo.cursorImg!)
				lastImg = CParsec.mouseInfo.cursorImg!
			}

			u?.frame = CGRect(x: Int(CParsec.mouseInfo.mouseX) - Int(Float(CParsec.mouseInfo.cursorHotX) * SettingsHandler.cursorScale),
							  y: Int(CParsec.mouseInfo.mouseY) - Int(Float(CParsec.mouseInfo.cursorHotY) * SettingsHandler.cursorScale),
							  width: Int(Float(CParsec.mouseInfo.cursorWidth) * SettingsHandler.cursorScale),
							  height: Int(Float(CParsec.mouseInfo.cursorHeight) * SettingsHandler.cursorScale))
			
		} else {
			u?.image = nil
		}
	}
	
	override func viewDidLoad() {
		glkView.viewDidLoad()
		touchController.viewDidLoad()
		gamePadController.viewDidLoad()
		
		u = UIImageView(frame: CGRect(x: 0,y: 0,width: 100, height: 100))
		view.addSubview(u!)
		
		becomeFirstResponder()
		setNeedsUpdateOfPrefersPointerLocked()
		
		let pointerInteraction = UIPointerInteraction(delegate: self)
		view.addInteraction(pointerInteraction)
		
		view.isMultipleTouchEnabled = true
		view.isUserInteractionEnabled = true

		let panGestureRecognizer = UIPanGestureRecognizer(target:self, action:#selector(self.handlePanGesture(_:)))
		panGestureRecognizer.delegate = self
		panGestureRecognizer.minimumNumberOfTouches = 1
		panGestureRecognizer.maximumNumberOfTouches = 2
		view.addGestureRecognizer(panGestureRecognizer)
		self.panGestureRecognizer = panGestureRecognizer

		let doubleTapDragGestureRecognizer = DoubleTapDragGestureRecognizer()
		doubleTapDragGestureRecognizer.delegate = self
		doubleTapDragGestureRecognizer.onFirstTapClick = { [weak self] location in
			self?.touchController.onTap(typeOfTap: 1, location: location)
		}
		doubleTapDragGestureRecognizer.onSelectionDrag = { [weak self] state, location in
			self?.touchController.onSelectionDrag(typeOfTap: 1, location: location, state: state)
		}
		view.addGestureRecognizer(doubleTapDragGestureRecognizer)
		self.doubleTapDragGestureRecognizer = doubleTapDragGestureRecognizer

		let twoFingerDoubleTapPasteGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerDoubleTapPaste(_:)))
		twoFingerDoubleTapPasteGestureRecognizer.numberOfTapsRequired = 2
		twoFingerDoubleTapPasteGestureRecognizer.numberOfTouchesRequired = 2
		twoFingerDoubleTapPasteGestureRecognizer.allowedTouchTypes = [0]
		view.addGestureRecognizer(twoFingerDoubleTapPasteGestureRecognizer)

		// Add tap gesture recognizer for single-finger touch (touchpad mode)
		let singleFingerTapGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(handleSingleFingerTap(_:)))
		singleFingerTapGestureRecognizer.numberOfTouchesRequired = 1
		singleFingerTapGestureRecognizer.allowedTouchTypes = [0, 2]
		singleFingerTapGestureRecognizer.delegate = self
		view.addGestureRecognizer(singleFingerTapGestureRecognizer)
		self.singleFingerTapGestureRecognizer = singleFingerTapGestureRecognizer

		// Add tap gesture recognizer for two-finger touch
		let twoFingerTapGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(handleTwoFingerTap(_:)))
		twoFingerTapGestureRecognizer.numberOfTouchesRequired = 2
		twoFingerTapGestureRecognizer.allowedTouchTypes = [0]
		twoFingerTapGestureRecognizer.require(toFail: twoFingerDoubleTapPasteGestureRecognizer)
		view.addGestureRecognizer(twoFingerTapGestureRecognizer)
		//		view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
		//		view.backgroundColor = UIColor(red: 0x66, green: 0xcc, blue: 0xff, alpha: 1.0)
		
		let threeFingerTapGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(handleThreeFinderTap(_:)))
		threeFingerTapGestureRecognizer.numberOfTouchesRequired = 3
		threeFingerTapGestureRecognizer.allowedTouchTypes = [0]
		view.addGestureRecognizer(threeFingerTapGestureRecognizer)
		
		let longPressGestureRecognizer = UILongPressGestureRecognizer(target:self, action:#selector(handleLongPress(_:)))
		longPressGestureRecognizer.numberOfTouchesRequired = 1
		longPressGestureRecognizer.allowedTouchTypes = [0, 2]
		longPressGestureRecognizer.minimumPressDuration = 0.28
		longPressGestureRecognizer.allowableMovement = 12
		view.addGestureRecognizer(longPressGestureRecognizer)

		panGestureRecognizer.require(toFail: longPressGestureRecognizer)
		
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(keyboardWillShow),
			name: UIResponder.keyboardWillShowNotification,
			object: nil
		)
		
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(keyboardWillHide),
			name: UIResponder.keyboardWillHideNotification,
			object: nil
		)

		setupClipboardQuickBar()
	}
	
	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		
		let h = size.height
		let w = size.width
		
		self.glkView.updateSize(width: w, height: h)
		CParsec.setFrame(w, h, UIScreen.main.scale)
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		if let parent = parent {
			parent.setChildForHomeIndicatorAutoHidden(self)
			parent.setChildViewControllerForPointerLock(self)
		}
		if let bar = clipboardQuickBar {
			view.bringSubviewToFront(bar)
		}
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		if let parent = parent {
			parent.setChildForHomeIndicatorAutoHidden(nil)
			parent.setChildViewControllerForPointerLock(nil)
		}
		NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
		NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
	}
	
	
	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		
		for press in presses {
			CParsec.sendKeyboardMessage(event:KeyBoardKeyEvent(input: press.key, isPressBegin: true) )
		}
		
	}
	
	override func pressesEnded (_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		
		for press in presses {
			CParsec.sendKeyboardMessage(event:KeyBoardKeyEvent(input: press.key, isPressBegin: false) )
		}
		
	}
	
	@objc func keyboardWillShow(_ notification: Notification) {
		if let keyboardFrame: NSValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
			let keyboardRectangle = keyboardFrame.cgRectValue
			keyboardHeight = keyboardRectangle.height - 50 // minus handle button height
		}
	}
	
	@objc func keyboardWillHide(_ notification: Notification) {
		view.frame.origin.y = 0
	}
	
}

extension ParsecViewController : UIGestureRecognizerDelegate {

	func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		if gestureRecognizer === singleFingerTapGestureRecognizer && SettingsHandler.cursorMode == .direct {
			return false
		}
		if gestureRecognizer === panGestureRecognizer,
		   doubleTapDragGestureRecognizer.isSelectionDragActive {
			return false
		}
		return true
	}

	@objc func handlePanGesture(_ gestureRecognizer:UIPanGestureRecognizer)
	{
		//		print("number = \(gestureRecognizer.numberOfTouches) status = \(gestureRecognizer.state.rawValue)")
		if gestureRecognizer.numberOfTouches == 2 {
			let velocity = gestureRecognizer.velocity(in: gestureRecognizer.view)
			
			if abs(velocity.y) > 2 {
				// Run your function when the user uses two fingers and swipes upwards
				CParsec.sendWheelMsg(x: 0, y: Int32(Float(velocity.y) / 20 * SettingsHandler.mouseSensitivity))
				return
			}
			if SettingsHandler.cursorMode == .direct {
				let location = gestureRecognizer.location(in:gestureRecognizer.view)
				touchController.onTouch(typeOfTap: 1, location: location, state: gestureRecognizer.state)
			}

		} else if gestureRecognizer.numberOfTouches == 1 {

			if SettingsHandler.cursorMode == .direct {
				let position = gestureRecognizer.location(in: gestureRecognizer.view)
				switch gestureRecognizer.state {
				case .began:
					directDragActive = true
					lastDirectDragPoint = position
					CParsec.sendMouseMessage(ParsecMouseButton(rawValue: 1), Int32(position.x), Int32(position.y), true)
				case .changed:
					CParsec.sendMousePosition(Int32(position.x), Int32(position.y))
					lastDirectDragPoint = position
				case .ended, .cancelled:
					if directDragActive {
						CParsec.sendMouseMessage(ParsecMouseButton(rawValue: 1), Int32(position.x), Int32(position.y), false)
						directDragActive = false
					}
				default:
					break
				}
			} else {
				if gestureRecognizer.state == .changed {
					let delta = gestureRecognizer.translation(in: gestureRecognizer.view)
					CParsec.sendMouseDelta(
						Int32(Float(delta.x) * SettingsHandler.mouseSensitivity * 0.45),
						Int32(Float(delta.y) * SettingsHandler.mouseSensitivity * 0.45)
					)
					gestureRecognizer.setTranslation(.zero, in: gestureRecognizer.view)
				}
			}

		}
		
		
	}
	
	@objc func handleSingleFingerTap(_ gestureRecognizer:UITapGestureRecognizer)
	{
		let location = gestureRecognizer.location(in:gestureRecognizer.view)
		touchController.onTap(typeOfTap: 1, location: location)
		
	}

	@objc func handleTwoFingerDoubleTapPaste(_ gestureRecognizer: UITapGestureRecognizer) {
		pasteFromClipboardTapped()
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
	}
	
	@objc func handleTwoFingerTap(_ gestureRecognizer:UITapGestureRecognizer)
	{
		let location : CGPoint;
		switch SettingsHandler.rightClickPosition {
		case .firstFinger:
			location = gestureRecognizer.location(ofTouch: 0, in: gestureRecognizer.view)
			break;
		case .secondFinger:
			location = gestureRecognizer.location(ofTouch: 1, in: gestureRecognizer.view)
			break
		default:
			location = gestureRecognizer.location(in: gestureRecognizer.view)
		}

		touchController.onTap(typeOfTap: 3, location: location)
	}
	
	@objc func handleThreeFinderTap(_ gestureRecognizer:UITapGestureRecognizer) {
		showKeyboard()
	}
	
	@objc func handleLongPress(_ gestureRecognizer:UIGestureRecognizer) {
		let button = ParsecMouseButton.init(rawValue: 1)
		
		if gestureRecognizer.state == .began{
			if SettingsHandler.cursorMode == .direct {
				lastLongPressPoint = gestureRecognizer.location(in: gestureRecognizer.view)
				CParsec.sendMouseMessage(button, Int32(lastLongPressPoint.x), Int32(lastLongPressPoint.y), true)
			} else {
				CParsec.sendMouseClickMessage(button, true)
				lastLongPressPoint = gestureRecognizer.location(in: gestureRecognizer.view)
			}
		} else if gestureRecognizer.state == .ended {
			if SettingsHandler.cursorMode == .direct {
				let location = gestureRecognizer.location(in: gestureRecognizer.view)
				CParsec.sendMouseMessage(button, Int32(location.x), Int32(location.y), false)
			} else {
				CParsec.sendMouseClickMessage(button, false)
			}
		} else if gestureRecognizer.state == .changed {
			let newLocation = gestureRecognizer.location(in: gestureRecognizer.view)
			if SettingsHandler.cursorMode == .direct {
				CParsec.sendMousePosition(Int32(newLocation.x), Int32(newLocation.y))
			} else {
				CParsec.sendMouseDelta(
					Int32(Float(newLocation.x - lastLongPressPoint.x) * SettingsHandler.mouseSensitivity),
					Int32(Float(newLocation.y - lastLongPressPoint.y) * SettingsHandler.mouseSensitivity)
				)
			}
			lastLongPressPoint = newLocation
		}
	}
	
}
	
extension ParsecViewController : UIPointerInteractionDelegate {
	func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
		return UIPointerStyle.hidden()
	}


	func pointerInteraction(_ inter: UIPointerInteraction, regionFor request: UIPointerRegionRequest, defaultRegion: UIPointerRegion) -> UIPointerRegion? {
		let loc = request.location
		if let iv = view!.hitTest(loc, with: nil) {
			let rect = view!.convert(iv.bounds, from: iv)
			let region = UIPointerRegion(rect: rect, identifier: iv.tag)
			return region
		}
		return nil
	}
	
}

class KeyBoardButton : UIButton {
	let keyText : String
	let isToggleable : Bool
	var isOn = false
	
	required init(keyText: String, isToggleable: Bool) {
		self.keyText = keyText
		self.isToggleable = isToggleable
		super.init(frame: .zero)
		addTarget(self, action: #selector(handleTouchDown), for: .touchDown)
		addTarget(self, action: #selector(handleTouchUp), for: [.touchUpInside, .touchDragExit, .touchCancel])
			
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	// Add a press-down animation for feedback
	@objc private func handleTouchDown() {
		self.alpha = 0.5
	}
	
	// Restore to normal state when touch ends
	@objc private func handleTouchUp() {
		UIView.animate(withDuration: 0.2) {
			self.alpha = 1.0
		}
	}
}

// MARK: - Virtual Keyboard
extension ParsecViewController : UIKeyInput, UITextInputTraits {
	var hasText: Bool {
		return true
	}
	
	var keyboardType: UIKeyboardType {
		get {
			return .asciiCapable
		}
		set {
			
		}
	}

	var autocorrectionType: UITextAutocorrectionType {
		.no
	}

	var spellCheckingType: UITextSpellCheckingType {
		.no
	}
	
	override var canBecomeFirstResponder: Bool {
		return true
	}

	func insertText(_ text: String) {
		if text.count == 1 {
			CParsec.sendVirtualKeyboardInput(text: text)
		} else {
			CParsec.sendVirtualKeyboardText(text)
		}
	}

	func deleteBackward() {
		CParsec.sendVirtualKeyboardInput(text: "BACKSPACE")
	}
	
	// copied from moonlight https://github.com/moonlight-stream/moonlight-ios/blob/022352c1667788d8626b659d984a290aa5c25e17/Limelight/Input/StreamView.m#L393
	override var inputAccessoryView: UIView? {
		
		if let keyboardAccessoriesView {
			return keyboardAccessoriesView
		}
		let containerView = UIStackView(frame: CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 94))
		containerView.translatesAutoresizingMaskIntoConstraints = false
		
		let customToolbarView = UIToolbar(frame: CGRect(x: 0, y: 50, width: self.view.bounds.size.width, height: 44))
		customToolbarView.translatesAutoresizingMaskIntoConstraints = false
		
		let scrollView = UIScrollView()
		scrollView.showsHorizontalScrollIndicator = false
		scrollView.translatesAutoresizingMaskIntoConstraints = false
		
		let buttonStackView = UIStackView()
		buttonStackView.axis = .horizontal
		buttonStackView.distribution = .equalSpacing
		buttonStackView.alignment = .center
		buttonStackView.spacing = 8
		buttonStackView.translatesAutoresizingMaskIntoConstraints = false

		let windowsBarButton = createKeyboardButton(displayText: "⌘", keyText: "LGUI", isToggleable: true)
		let tabBarButton = createKeyboardButton(displayText: "⇥", keyText: "TAB", isToggleable: false)
		let shiftBarButton = createKeyboardButton(displayText: "⇧", keyText: "SHIFT", isToggleable: true)
		let escapeBarButton = createKeyboardButton(displayText: "⎋", keyText: "UIKeyInputEscape", isToggleable: false)
		let controlBarButton = createKeyboardButton(displayText: "⌃", keyText: "CONTROL", isToggleable: true)
		let altBarButton = createKeyboardButton(displayText: "⌥", keyText: "LALT", isToggleable: true)
		let deleteBarButton = createKeyboardButton(displayText: "Del", keyText: "DELETE", isToggleable: false)
		let selectAllBarButton = createClipboardButton(displayText: "Todo", action: #selector(sendSelectAllTapped))
		let pasteBarButton = createClipboardButton(displayText: "Pegar", action: #selector(pasteFromClipboardTapped))
		let copyBarButton = createClipboardButton(displayText: "Copiar", action: #selector(sendCopyShortcutTapped))
		let cutBarButton = createClipboardButton(displayText: "Cortar", action: #selector(sendCutShortcutTapped))
		let pasteShortcutBarButton = createClipboardButton(displayText: "⌃V", action: #selector(sendPasteShortcutTapped))
		let copyMacBarButton = createClipboardButton(displayText: "⌘C", action: #selector(sendCopyMacShortcutTapped))
		let pasteMacBarButton = createClipboardButton(displayText: "⌘V", action: #selector(sendPasteMacShortcutTapped))
		let cutMacBarButton = createClipboardButton(displayText: "⌘X", action: #selector(sendCutMacShortcutTapped))
		let selectAllMacBarButton = createClipboardButton(displayText: "⌘A", action: #selector(sendSelectAllMacShortcutTapped))
		let copyCtrlBarButton = createClipboardButton(displayText: "⌃C", action: #selector(sendCopyShortcutTapped))
		let selectAllCtrlBarButton = createClipboardButton(displayText: "⌃A", action: #selector(sendSelectAllTapped))
		let f1Button = createKeyboardButton(displayText: "F1", keyText: "F1", isToggleable: false)
		let f2Button = createKeyboardButton(displayText: "F2", keyText: "F2", isToggleable: false)
		let f3Button = createKeyboardButton(displayText: "F3", keyText: "F3", isToggleable: false)
		let f4Button = createKeyboardButton(displayText: "F4", keyText: "F4", isToggleable: false)
		let f5Button = createKeyboardButton(displayText: "F5", keyText: "F5", isToggleable: false)
		let f6Button = createKeyboardButton(displayText: "F6", keyText: "F6", isToggleable: false)
		let f7Button = createKeyboardButton(displayText: "F7", keyText: "F7", isToggleable: false)
		let f8Button = createKeyboardButton(displayText: "F8", keyText: "F8", isToggleable: false)
		let f9Button = createKeyboardButton(displayText: "F9", keyText: "F9", isToggleable: false)
		let f10Button = createKeyboardButton(displayText: "F10", keyText: "F10", isToggleable: false)
		let f11Button = createKeyboardButton(displayText: "F11", keyText: "F11", isToggleable: false)
		let f12Button = createKeyboardButton(displayText: "F12", keyText: "F12", isToggleable: false)
		let upButton = createKeyboardButton(displayText: "↑", keyText: "UP", isToggleable: false)
		let downButton = createKeyboardButton(displayText: "↓", keyText: "DOWN", isToggleable: false)
		let leftButton = createKeyboardButton(displayText: "←", keyText: "LEFT", isToggleable: false)
		let rightButton = createKeyboardButton(displayText: "→", keyText: "RIGHT", isToggleable: false)
		

		let buttons = [windowsBarButton, escapeBarButton, tabBarButton, shiftBarButton, controlBarButton, altBarButton, deleteBarButton,
					   selectAllBarButton, pasteBarButton, copyBarButton, cutBarButton,
					   selectAllCtrlBarButton, copyCtrlBarButton, pasteShortcutBarButton,
					   copyMacBarButton, pasteMacBarButton, cutMacBarButton, selectAllMacBarButton,
					   f1Button, f2Button, f3Button, f4Button, f5Button, f6Button, f7Button, f8Button, f9Button, f10Button, f11Button, f12Button,
								   upButton, downButton, leftButton, rightButton
		]
		
		for button in buttons {
			buttonStackView.addArrangedSubview(button)
		}
		
		scrollView.addSubview(buttonStackView)
		
		
		
		let scrollViewContainer = UIView()
		scrollViewContainer.translatesAutoresizingMaskIntoConstraints = false
		scrollViewContainer.addSubview(scrollView)

		
		NSLayoutConstraint.activate([
			scrollView.leadingAnchor.constraint(equalTo: scrollViewContainer.leadingAnchor),
			scrollView.trailingAnchor.constraint(equalTo: scrollViewContainer.trailingAnchor),
			scrollView.topAnchor.constraint(equalTo: scrollViewContainer.topAnchor),
			scrollView.bottomAnchor.constraint(equalTo: scrollViewContainer.bottomAnchor)
		])
		
		NSLayoutConstraint.activate([
			scrollViewContainer.heightAnchor.constraint(equalToConstant: 44),
			scrollViewContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 100)
		])

		// 10. Set constraints for the stack view inside the scroll view
		NSLayoutConstraint.activate([
			buttonStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
			buttonStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
			buttonStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
			buttonStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
			buttonStackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
		])
		
		
		let container2 = UIStackView()
		container2.axis = .horizontal
		container2.distribution = .fill
		container2.alignment = .center
		container2.addArrangedSubview(scrollViewContainer)
		
		let doneButton2 = UIButton()
		doneButton2.setTitle("Done", for: .normal)
		doneButton2.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
		if #available(iOS 15.0, *) {
			doneButton2.setTitleColor(.tintColor,  for: .normal)
		}
		container2.addArrangedSubview(doneButton2)

		let scrollViewBarButton = UIBarButtonItem(customView: container2)
		
		customToolbarView.setItems([scrollViewBarButton], animated: false)
		
		
		// Create a draggable handle button
		let handleButton = UIButton(type: .system)
		handleButton.setTitle("↑↓", for: .normal)
		handleButton.backgroundColor = UIColor.systemGray.withAlphaComponent(0.5)
		handleButton.translatesAutoresizingMaskIntoConstraints = false
		
		let panGestureRecognizer = UIPanGestureRecognizer(target:self, action:#selector(self.handleDragGesture(_:)))
		panGestureRecognizer.maximumNumberOfTouches = 1
		handleButton.addGestureRecognizer(panGestureRecognizer)
		
		handleButton.layer.cornerRadius = 20
		containerView.addSubview(handleButton)
		
		containerView.addSubview(customToolbarView)
		
		NSLayoutConstraint.activate([
			customToolbarView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
			customToolbarView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
			customToolbarView.heightAnchor.constraint(equalToConstant: 44)
		])
		
		NSLayoutConstraint.activate([
			handleButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
			handleButton.topAnchor.constraint(equalTo: containerView.topAnchor),
			handleButton.widthAnchor.constraint(equalToConstant: 40),
			handleButton.heightAnchor.constraint(equalToConstant: 40)
		])
		
		NSLayoutConstraint.activate([
			containerView.heightAnchor.constraint(equalToConstant: 94),
			containerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
		])
		
		keyboardAccessoriesView = containerView
		return containerView
	}
	
	func createKeyboardButton(displayText: String, keyText: String, isToggleable: Bool) -> UIButton {
		let button = KeyBoardButton(keyText: keyText, isToggleable: isToggleable)
		button.setTitle(displayText, for: .normal)
		button.titleLabel?.font = UIFont(name: "System", size: 10.0)
		button.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
		button.titleLabel?.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
		if let label = button.titleLabel {
			label.textAlignment = .center
		}
		button.backgroundColor = .black
		button.layer.cornerRadius = 3.0
		
		button.titleLabel?.contentMode = .scaleAspectFit

		button.addTarget(target, action: #selector(toolbarButtonClicked(_:)), for: .touchUpInside)
		
		return button
	}

	func createClipboardButton(displayText: String, action: Selector) -> UIButton {
		let button = UIButton(type: .system)
		button.setTitle(displayText, for: .normal)
		button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
		button.titleLabel?.adjustsFontSizeToFitWidth = true
		button.titleLabel?.minimumScaleFactor = 0.7
		button.frame = CGRect(x: 0, y: 0, width: 52, height: 40)
		if let label = button.titleLabel {
			label.textAlignment = .center
		}
		button.backgroundColor = .black
		button.setTitleColor(.white, for: .normal)
		button.layer.cornerRadius = 6.0
		button.addTarget(self, action: action, for: .touchUpInside)
		return button
	}

	func setupClipboardQuickBar() {
		let blur = UIBlurEffect(style: .systemUltraThinMaterialDark)
		let bar = UIVisualEffectView(effect: blur)
		bar.translatesAutoresizingMaskIntoConstraints = false
		bar.layer.cornerRadius = 12
		bar.clipsToBounds = true
		bar.alpha = 0.82

		let scrollView = UIScrollView()
		scrollView.showsHorizontalScrollIndicator = false
		scrollView.translatesAutoresizingMaskIntoConstraints = false

		let stack = UIStackView()
		stack.axis = .horizontal
		stack.spacing = 8
		stack.alignment = .center
		stack.translatesAutoresizingMaskIntoConstraints = false

		let items: [(String, Selector)] = [
			("Todo", #selector(sendSelectAllTapped)),
			("Copiar", #selector(sendCopyShortcutTapped)),
			("Pegar", #selector(pasteFromClipboardTapped)),
			("Cortar", #selector(sendCutShortcutTapped)),
			("⌃A", #selector(sendSelectAllTapped)),
			("⌃C", #selector(sendCopyShortcutTapped)),
			("⌃V", #selector(sendPasteShortcutTapped)),
			("⌘A", #selector(sendSelectAllMacShortcutTapped)),
			("⌘C", #selector(sendCopyMacShortcutTapped)),
			("⌘V", #selector(sendPasteMacShortcutTapped)),
			("⌘X", #selector(sendCutMacShortcutTapped)),
		]
		for (title, action) in items {
			stack.addArrangedSubview(createQuickActionButton(title: title, action: action))
		}

		scrollView.addSubview(stack)
		bar.contentView.addSubview(scrollView)
		view.addSubview(bar)

		NSLayoutConstraint.activate([
			bar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
			bar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
			bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
			scrollView.leadingAnchor.constraint(equalTo: bar.contentView.leadingAnchor, constant: 6),
			scrollView.trailingAnchor.constraint(equalTo: bar.contentView.trailingAnchor, constant: -6),
			scrollView.topAnchor.constraint(equalTo: bar.contentView.topAnchor, constant: 6),
			scrollView.bottomAnchor.constraint(equalTo: bar.contentView.bottomAnchor, constant: -6),
			stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
			stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
			stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
			stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
			stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
		])

		clipboardQuickBar = bar
	}

	func createQuickActionButton(title: String, action: Selector) -> UIButton {
		let button = UIButton(type: .system)
		button.setTitle(title, for: .normal)
		button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
		button.titleLabel?.adjustsFontSizeToFitWidth = true
		button.titleLabel?.minimumScaleFactor = 0.7
		button.backgroundColor = UIColor.white.withAlphaComponent(0.16)
		button.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
		button.layer.borderWidth = 0.5
		button.setTitleColor(UIColor.white.withAlphaComponent(0.95), for: .normal)
		button.layer.cornerRadius = 8
		button.heightAnchor.constraint(equalToConstant: 40).isActive = true
		button.widthAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
		button.addTarget(self, action: action, for: .touchUpInside)
		return button
	}

	@objc func pasteFromClipboardTapped() {
		guard let text = UIPasteboard.general.string, !text.isEmpty else {
			UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
			return
		}
		CParsec.sendVirtualKeyboardText(text)
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
	}

	@objc func sendCopyShortcutTapped() {
		CParsec.sendKeyChord(modifierKeyText: "CONTROL", keyText: "C")
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
	}

	@objc func sendCutShortcutTapped() {
		CParsec.sendKeyChord(modifierKeyText: "CONTROL", keyText: "X")
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
	}

	@objc func sendPasteShortcutTapped() {
		CParsec.sendKeyChord(modifierKeyText: "CONTROL", keyText: "V")
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
	}

	@objc func sendSelectAllTapped() {
		CParsec.sendKeyChord(modifierKeyText: "CONTROL", keyText: "A")
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
	}

	@objc func sendCopyMacShortcutTapped() {
		CParsec.sendKeyChord(modifierKeyText: "LGUI", keyText: "C")
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
	}

	@objc func sendPasteMacShortcutTapped() {
		CParsec.sendKeyChord(modifierKeyText: "LGUI", keyText: "V")
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
	}

	@objc func sendCutMacShortcutTapped() {
		CParsec.sendKeyChord(modifierKeyText: "LGUI", keyText: "X")
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
	}

	@objc func sendSelectAllMacShortcutTapped() {
		CParsec.sendKeyChord(modifierKeyText: "LGUI", keyText: "A")
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
	}
	
	@objc func toolbarButtonClicked(_ sender: KeyBoardButton) {
		let isToggleable = sender.isToggleable
		var isOn = sender.isOn

		if isToggleable {
			isOn.toggle()
			if isOn {
				sender.backgroundColor = .lightGray
			} else {
				sender.backgroundColor = .black
			}
		}

		sender.isOn = isOn
		let keyText = sender.keyText

		
		if isToggleable {
			if isOn {
				CParsec.sendVirtualKeyboardInput(text: keyText, isOn: true)
			} else {
				CParsec.sendVirtualKeyboardInput(text: keyText, isOn: false)
			}
		} else {
			CParsec.sendVirtualKeyboardInput(text: keyText)
		}
		
	}
	
	@objc func handleDragGesture(_ gestureRecognizer:UIPanGestureRecognizer) {
		let v = view.frame.origin.y + gestureRecognizer.velocity(in: nil).y / 50.0
		let newY = ParsecSDKBridge.clamp(v, minValue: -keyboardHeight, maxValue: 0)
		view.frame.origin.y = newY
	}

	@objc func doneTapped() {
		// Resign first responder to dismiss the keyboard
		resignFirstResponder()
	}
	
	@objc func showKeyboard() {
		becomeFirstResponder()
	}
	
}
