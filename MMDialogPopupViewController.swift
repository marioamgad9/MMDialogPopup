//
//  MMDialogPopupViewController.swift
//  MMDialogPopup
//
//  Created by Mario Mouris on 10/8/18.
//  Copyright © 2018 Mario Mouris. All rights reserved.
//

import UIKit

protocol DialogPopupDelegate: class {
    var popupViewController: DialogPopupViewController? { get set }
    var allowsTapToDismissPopupDialog: Bool { get }
    var allowsSwipeToDismissPopupDialog: Bool { get }
}

class DialogPopupViewController: UIViewController {
    
    //MARK: - Public Interface
    var cornerRadius: CGFloat
    var disableTapToDismiss = false
    var disableSwipeToDismiss = false
    
    func show(onViewController viewController: UIViewController) {
        self.modalPresentationStyle = .overCurrentContext
        viewController.present(self, animated: false)
    }
    
    func close(completionHandler: (() -> Void)? = nil) {
        animateOut(completionHandler: completionHandler)
    }
    
    //MARK: - Private Properties
    private let introAnimationDuration = 0.6
    private let outroAnimationDuration = 0.8
    private let backgroundOpacity = CGFloat(0.4)
    
    private let containerView = UIView(frame: .zero)
    private let contentViewController: UIViewController
    private let contentView: UIView
    
    private var hasAnimatedIn = false
    
    private var state = State.animatingIn
    private var swipeOffset = CGFloat(0)
    
    private var displayLink: CADisplayLink!
    private var lastTimeStamp: CFTimeInterval?
    
    private var containerCenterYConstraint: NSLayoutConstraint!
    private var containerOffscreenConstraint: NSLayoutConstraint!
    
    private var tapRecognizer: UITapGestureRecognizer!
    private var panRecognizer: UIPanGestureRecognizer!
    
    private var keyboardIsVisible = false
    
    private var popupProtocolResponder: DialogPopupDelegate? {
        if let protocolResponder = contentViewController as? DialogPopupDelegate {
            return protocolResponder
        } else {
            return nil
        }
    }
    
    //MARK: - State type
    enum State {
        case animatingIn
        case idle
        case panning
        case animatingOut
        case physicsOut(PhysicsState)
    }
    
    struct PhysicsState {
        let acceleration = CGFloat(9999)
        var velocity = CGFloat(0)
    }
    
    //MARK: - Initializers
    init(contentViewControler viewController: UIViewController, cornerRadius: Int = Int(Dimens.cornerRadius)) {
        contentViewController = viewController
        contentView = viewController.view
        self.cornerRadius = CGFloat(cornerRadius)
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.clear
        
        //Container view
        containerView.layer.cornerRadius = cornerRadius
        containerView.layer.masksToBounds = true
        view.addSubview(containerView)
        containerView.isUserInteractionEnabled = false
        
        //Content view
        addChild(contentViewController)
        containerView.addSubview(contentView)
        
        //Apply constraints
        applyContainerViewConstraints()
        applyContentViewConstraints()
        containerOffscreenConstraint.isActive = true
        
        //Tap outside recognizer
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapOutside))
        tapRecognizer.delegate = self
        view.addGestureRecognizer(tapRecognizer)
        
        //Pan recognizer
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPan))
        panRecognizer.delegate = self
        view.addGestureRecognizer(panRecognizer)
        
        //Display link
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink.add(to: .current, forMode: .common)
        
        //Popup protocol responder
        popupProtocolResponder?.popupViewController = self
        
        //Subscribe to keyboard notifications
        subscribeToKeyboardNotifciations()
        
        //Add listener to dismiss keyboard on click
        contentViewController.hideKeyboard()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !hasAnimatedIn {
            animateIn()
            hasAnimatedIn = true
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        displayLink.invalidate()
    }
}

//MARK: - Keyboard notifications
extension DialogPopupViewController {
    func subscribeToKeyboardNotifciations() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow(with:)),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide(with:)),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
    }
    
    @objc func keyboardWillShow(with notification: Notification) {
        let key = "UIKeyboardFrameEndUserInfoKey"
        guard let keyboardFrame = notification.userInfo?[key] as? NSValue else {return}
        
        let keyboardHeight = keyboardFrame.cgRectValue.height + 8
        
        //Update keyboardIsVisible variable
        keyboardIsVisible = true
        
        //Push center constraint
        containerCenterYConstraint.constant = -keyboardHeight/2
        
        //Update with animations
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func keyboardWillHide(with notification: Notification) {
        //Update keyboardIsVisible variable
        keyboardIsVisible = false
        
        //Return to center constraint
        containerCenterYConstraint.constant = 0
        
        //Update with animations
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
}

//MARK: - Animations
extension DialogPopupViewController {
    private func animate(fromPan panRecognizer: UIPanGestureRecognizer) {
        let animateOutThreshold = CGFloat(50)
        let velocity = panRecognizer.velocity(in: view).y
        
        if velocity > animateOutThreshold {
            //Animate out
            let physicsState = PhysicsState(velocity: velocity)
            state = .physicsOut(physicsState)
        } else {
            //Snap back
            animateSnapBackToCenter()
        }
    }
    
    private func animateSnapBackToCenter() {
        swipeOffset = 0
        view.setNeedsUpdateConstraints()
        
        UIView.animate(withDuration: introAnimationDuration,
                       delay: 0.0,
                       usingSpringWithDamping: 0.7,
                       initialSpringVelocity: 0,
                       options: [],
                       animations: {
                        self.view.layoutIfNeeded()
        }, completion: { _ in })
    }
    
    private func animateIn() {
        //Animate background color
        UIView.animate(withDuration: introAnimationDuration,
                       delay: 0.0,
                       options: [.curveEaseInOut, .allowUserInteraction],
                       animations: {
                        self.view.backgroundColor = UIColor(white: 0, alpha: self.backgroundOpacity)
        }, completion: nil)
        
        //Animate container on screen
        containerOffscreenConstraint.isActive = false
        self.view.setNeedsUpdateConstraints()
        
        UIView.animate(withDuration: introAnimationDuration,
                       delay: 0.0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0,
                       options: [.allowUserInteraction],
                       animations: {
                        self.view.layoutIfNeeded()
        }, completion: { _ in
            self.containerView.isUserInteractionEnabled = true
            self.state = .idle
        })
    }
    
    private func animateOut(completionHandler: (() -> Void)? = nil) {
        view.isUserInteractionEnabled = false
        state = .animatingOut
        
        //Animate background color
        UIView.animate(withDuration: outroAnimationDuration,
                       delay: 0.0,
                       options: [.curveEaseInOut],
                       animations: {
                        self.view.backgroundColor = UIColor.clear
        })
        
        //Animate container off screen
        containerOffscreenConstraint.isActive = true
        view.setNeedsUpdateConstraints()
        
        UIView.animate(withDuration: outroAnimationDuration,
                       delay: 0.0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0,
                       options: [],
                       animations: {
                        self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: completionHandler)
        })
    }
}

//MARK: - Gestures
extension DialogPopupViewController: UIGestureRecognizerDelegate {
    @objc private func tapOutside() {
        //Hide keyboard if visible and return
        if keyboardIsVisible {
            dismissKeyboard()
            return
        }
        
        if let protocolResponder = popupProtocolResponder {
            if protocolResponder.allowsTapToDismissPopupDialog {
                animateOut()
            }
        } else {
            animateOut()
        }
    }
    
    @objc private func didPan(recognizer: UIPanGestureRecognizer) {
        if state == .animatingIn {
            //If panned while animating in, stop all animations
            state = .idle
            self.view.layer.removeAllAnimations()
            self.containerView.layer.removeAllAnimations()
        }
        
        //Make sure that the state is either idle or panning
        guard state == . idle || state == .panning else { return }
        
        let applyOffset = {
            self.swipeOffset = recognizer.translation(in: self.view).y
            self.view.setNeedsUpdateConstraints()
        }
        
        switch recognizer.state {
        case .possible:
            break
        case .began:
            state = .panning
            applyOffset()
        case .changed:
            state = .panning
            applyOffset()
        case .cancelled:
            break
        case . failed:
            break
        case .ended:
            animate(fromPan: recognizer)
        }
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let responder = popupProtocolResponder, gestureRecognizer === panRecognizer {
            //Return if keyboard is shown
            if self.keyboardIsVisible { return false }
            
            //Pan gesture triggered, check if swipe is enabled
            if self.disableTapToDismiss {
                return false
            }
            
            return responder.allowsSwipeToDismissPopupDialog
        }
        
        if gestureRecognizer == tapRecognizer {
            //Tap gesture triggered, check if it is outside the view
            if self.disableTapToDismiss {
                //Don't dismiss if the disable on tap is disabled
                return false
            }
            
            let location = tapRecognizer.location(in: view)
            return !containerView.frame.contains(location)
        }
        
        return true
    }
}

//MARK: - Constraints
extension DialogPopupViewController {
    override func updateViewConstraints() {
        super.updateViewConstraints()
        
        if swipeOffset < 0 {
            //Elastic pull upwards
            let offset = -swipeOffset
            let offsetPct = (offset / view.bounds.size.width / 2)
            let elasticity = CGFloat(3)
            let percent = offsetPct / (1.0 + (offsetPct * elasticity))
            
            containerCenterYConstraint.constant = -(percent * view.bounds.size.width / 2)
        } else {
            //Regular tracking downwards
            containerCenterYConstraint.constant = swipeOffset
        }
    }
    
    private func applyContentViewConstraints() {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        [NSLayoutConstraint.Attribute.left, .right, .top, .bottom].forEach{
            
            let constraint = NSLayoutConstraint(item: contentView,
                                                attribute: $0,
                                                relatedBy: .equal,
                                                toItem: containerView,
                                                attribute: $0,
                                                multiplier: 1.0,
                                                constant: 0)
            containerView.addConstraint(constraint)
        }
    }
    
    private func applyContainerViewConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let sideMargin = CGFloat(16)
        let verticalMargins = CGFloat(16)
        
        let left = NSLayoutConstraint(item: containerView,
                                      attribute: .left,
                                      relatedBy: .equal,
                                      toItem: view,
                                      attribute: .left,
                                      multiplier: 1.0,
                                      constant: sideMargin)
        
        let right = NSLayoutConstraint(item: containerView,
                                       attribute: .right,
                                       relatedBy: .equal,
                                       toItem: view,
                                       attribute: .right,
                                       multiplier: 1.0,
                                       constant: -sideMargin)
        
        containerCenterYConstraint = NSLayoutConstraint(item: containerView,
                                                        attribute: .centerY,
                                                        relatedBy: .equal,
                                                        toItem: view,
                                                        attribute: .centerY,
                                                        multiplier: 1.0,
                                                        constant: 0)
        containerCenterYConstraint.priority = UILayoutPriority.defaultLow
        
        let limitHeight = NSLayoutConstraint(item: containerView,
                                             attribute: .height,
                                             relatedBy: .lessThanOrEqual,
                                             toItem: view,
                                             attribute: .height,
                                             multiplier: 1.0,
                                             constant: -verticalMargins*2)
        limitHeight.priority = UILayoutPriority.defaultHigh
        
        containerOffscreenConstraint = NSLayoutConstraint(item: containerView,
                                                          attribute: .top,
                                                          relatedBy: .equal,
                                                          toItem: view,
                                                          attribute: .bottom,
                                                          multiplier: 1.0,
                                                          constant: 0)
        containerOffscreenConstraint.priority = UILayoutPriority.required
        
        view.addConstraints([left, right, containerCenterYConstraint, limitHeight, containerOffscreenConstraint])
    }
}

//MARK: - Display link
extension DialogPopupViewController {
    @objc func tick() {
        //We need a previous time stamp to work with, bail if we don't have one
        guard let last = lastTimeStamp else {
            lastTimeStamp = displayLink.timestamp
            return
        }
        
        //Calculate dt
        let dt = displayLink.timestamp - last
        
        //Save current time
        lastTimeStamp = displayLink.timestamp
        
        //If we're using physics to animate out, update the simulation
        guard case var State.physicsOut(physicsState) = state else {
            return
        }
        
        physicsState.velocity += CGFloat(dt) * physicsState.acceleration
        
        swipeOffset += physicsState.velocity * CGFloat(dt)
        
        view.setNeedsUpdateConstraints()
        state = .physicsOut(physicsState)
        
        //Remove if the content view is off screen
        if swipeOffset > view.bounds.size.height / 2 {
            dismiss(animated: false)
        }
    }
}

//MARK: - Determine equality between two states
func ==(lhs: DialogPopupViewController.State, rhs: DialogPopupViewController.State) -> Bool {
    
    switch (lhs, rhs) {
    case (.animatingIn, .animatingIn):
        return true
    case (.idle, .idle):
        return true
    case (.panning, .panning):
        return true
    case (.physicsOut, .physicsOut):
        return true
    default:
        return false
    }
}
