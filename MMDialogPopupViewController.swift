//
//  MMDialogPopupViewController.swift
//  MMDialogPopup
//
//  Created by Mario Mouris on 10/8/18.
//  Copyright © 2018 Mario Mouris. All rights reserved.
//

import UIKit

class MMDialogPopupViewController: UIViewController {
    
    //MARK: - Public Interface
    var cornerRadius: CGFloat
    var disableSwipeToDismiss = false
    var disableTapToDismiss = false
    
    func show(onViewController viewController: UIViewController) {
        self.modalPresentationStyle = .overCurrentContext
        viewController.present(self, animated: false)
    }
    
    func close() {
        animateOut()
    }
    
    //MARK: - Private Properties
    private let introAnimationDuration = 0.6
    private let outroAnimationDuration = 1.0
    private let backgroundOpacity = CGFloat(0.4)
    
    private let containerView = UIView(frame: .zero)
    private let contentViewController: UIViewController
    private let contentView: UIView
    
    private var containerCenterYConstraint: NSLayoutConstraint!
    private var containerOffscreenConstraint: NSLayoutConstraint!
    
    private var tapRecognizer: UITapGestureRecognizer!
    
    //MARK: - Initializers
    init(contentViewControler viewController: UIViewController, cornerRadius: Int = 8) {
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
        
        //Container View
        containerView.layer.cornerRadius = cornerRadius
        containerView.layer.masksToBounds = true
        view.addSubview(containerView)
        containerView.isUserInteractionEnabled = false
        
        //Content View
        addChild(contentViewController)
        containerView.addSubview(contentView)
        
        //Apply constraints
        applyContainerViewConstraints()
        applyContentViewConstraints()
        containerOffscreenConstraint.isActive = true
        
        //Tap Away Recognizer
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapOutside))
        tapRecognizer.delegate = self
        view.addGestureRecognizer(tapRecognizer)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        animateIn()
    }
}

//MARK: - Animations
extension MMDialogPopupViewController {
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
                       usingSpringWithDamping: 0.84,
                       initialSpringVelocity: 0,
                       options: [.allowUserInteraction],
                       animations: {
                        self.view.layoutIfNeeded()
        }, completion: { _ in
            self.containerView.isUserInteractionEnabled = true
        })
    }
    private func animateOut() {
        view.isUserInteractionEnabled = false
        
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
        }, completion: {
            _ in
            self.dismiss(animated: false, completion: nil)
        })
    }
}

//MARK: - Gestures
extension MMDialogPopupViewController: UIGestureRecognizerDelegate {
    @objc private func tapOutside() {
        animateOut()
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
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
extension MMDialogPopupViewController {
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
