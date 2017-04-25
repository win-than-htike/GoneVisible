//
//  UIView+GoneVisible.swift
//  GoneVisible
//
//  Created by Teruto Yamasaki on 2017/04/19.
//  Copyright © 2017年 Teruto Yamasaki. All rights reserved.
//

import UIKit

public enum SpaceAttribute {
    case top
    case bottom
    case leading
    case trailing
    
    func layoutAttribute() -> NSLayoutAttribute {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }
}

public enum SizeAttribute {
    case height
    case width
    
    func layoutAttribute() -> NSLayoutAttribute {
        switch self {
        case .height: return .height
        case .width: return .width
        }
    }
}

extension NSLayoutConstraint {
    
    // MARK: - Added Stored Property
    
    @nonobjc static private var originalConstantKey  = "originalConstant"
    
    private var originalConstant: CGFloat? {
        get {
            return objc_getAssociatedObject(self, &NSLayoutConstraint.originalConstantKey) as? CGFloat
        }
        set {
            objc_setAssociatedObject(self, &NSLayoutConstraint.originalConstantKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // MARK: - Change Constant
    
    fileprivate func setGoneConstant() {
        guard self.originalConstant == nil else { return }
        self.originalConstant = self.constant
        self.constant = 0
    }
    
    fileprivate func setVisibleConstant() {
        guard let originalConstant = self.originalConstant else { return }
        self.constant = originalConstant
        self.originalConstant = nil
    }
    
    // MARK: - Determine Constraint
    
    fileprivate func isAspectRatio() -> Bool {
       return (self.firstAttribute == .height && self.secondAttribute == .width)
        || (self.firstAttribute == .width && self.secondAttribute == .height)
    }
    
    fileprivate func isHeight() -> Bool {
        return self.firstAttribute == .height && self.secondAttribute == .notAnAttribute
    }
    
    fileprivate func isWidth() -> Bool {
        return self.firstAttribute == .width && self.secondAttribute == .notAnAttribute
    }
    
    fileprivate func isSpacing(itemView: UIView, attribute: NSLayoutAttribute) -> Bool {
        return (self.firstItem as? UIView == itemView && self.firstAttribute == attribute)
            || (self.secondItem as? UIView == itemView && self.secondAttribute == attribute)
    }
    
    fileprivate func isEqual(itemView: UIView, attribute: NSLayoutAttribute) -> Bool {
        return (self.firstItem as? UIView == itemView && self.secondItem != nil && self.firstAttribute == attribute)
            || (self.secondItem as? UIView == itemView && self.secondAttribute == attribute)
    }

}

extension UIView {
    
    // MARK: - Added Stored Property
    
    @nonobjc static private var isGoneKey  = "isGone"
    @nonobjc static private var aspectRatioConstraintsKey  = "aspectRatioConstraints"
    @nonobjc static private var equalHeightConstraintsKey  = "equalHeightConstraints"
    @nonobjc static private var equalWidthConstraintsKey  = "equalWidthConstraints"
    
    open private(set) var isGone: Bool {
        get {
            return (objc_getAssociatedObject(self, &UIView.isGoneKey) as? Bool) ?? false
        }
        set {
            objc_setAssociatedObject(self, &UIView.isGoneKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private var aspectRatioConstraints: [NSLayoutConstraint]? {
        get {
            return objc_getAssociatedObject(self, &UIView.aspectRatioConstraintsKey) as? [NSLayoutConstraint]
        }
        set {
            objc_setAssociatedObject(self, &UIView.aspectRatioConstraintsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private var equalHeightConstraints: [NSLayoutConstraint]? {
        get {
            return objc_getAssociatedObject(self, &UIView.equalHeightConstraintsKey) as? [NSLayoutConstraint]
        }
        set {
            objc_setAssociatedObject(self, &UIView.equalHeightConstraintsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private var equalWidthConstraints: [NSLayoutConstraint]? {
        get {
            return objc_getAssociatedObject(self, &UIView.equalWidthConstraintsKey) as? [NSLayoutConstraint]
        }
        set {
            objc_setAssociatedObject(self, &UIView.equalWidthConstraintsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // MARK: - gone / visible Method
    
    /// Size constraint of self is changed to 0, realizing an Android-like gone.
    ///
    /// If self has no size constraint, it will be added.
    ///
    /// - Parameter direction: Normally, both the height and width constraints are set to 0, but 
    /// if you want to set either one of the constraints to 0.
    ///
    /// - Parameter spaces: At the same time, specify when you want to set the space top, bottom,
    /// leading and trailing to 0.
    ///
    /// - Parameter completion: Blocks to be executed upon completion.
    ///
    open func gone(direction: SizeAttribute? = nil, spaces: [SpaceAttribute]? = nil, completion: (() -> ())? = nil) {
        self.isGone = true
        
        // Find size constraints to make it 0 constant, if not create it.
        if direction == .height {
            var heightConstraints = self.findHeightConstraints()
            if heightConstraints == nil {
                heightConstraints = [self.addHeightConstraint()]
            }
            _ = heightConstraints?.map { $0.setGoneConstant() }
        } else if direction == .width {
            var widthConstraints = self.findWidthConstraints()
            if widthConstraints == nil  {
                widthConstraints = [self.addWidthConstraint()]
            }
            _ = widthConstraints?.map { $0.setGoneConstant() }
        } else {
            var heightConstraints = self.findHeightConstraints()
            var widthConstraints = self.findWidthConstraints()
            if widthConstraints == nil && heightConstraints == nil {
                heightConstraints = [self.addHeightConstraint()]
                widthConstraints = [self.addWidthConstraint()]
            }
            _ = heightConstraints?.map { $0.setGoneConstant() }
            _ = widthConstraints?.map { $0.setGoneConstant() }
        }


        // Inactivate constraints that disturbs becoming 0 constant.
        self.aspectRatioConstraints = self.findAspectRatioConstraints()
        _ = self.aspectRatioConstraints?.map { $0.isActive = false }
        
        self.equalWidthConstraints = self.findEqualConstraints(itemView: self, attribute: .width)
        _ = self.equalWidthConstraints?.map { $0.isActive = false }
            
        self.equalHeightConstraints = self.findEqualConstraints(itemView: self, attribute: .height)
        _ = self.equalHeightConstraints?.map { $0.isActive = false }
        
        // Set space constraints to 0 constant.
        _ = spaces?.map { self.goneSpacing( $0.layoutAttribute()) }
        
        self.setNeedsUpdateConstraints()
        
        completion?()
    }
    
    /// Restore the constraint set to 0 by gone to the original constant.
    ///
    /// Space constraints are also restored.
    ///
    /// - Parameter completion: Blocks to be executed upon completion.
    ///
    open func visible(completion: (() -> ())? = nil) {
        guard self.isGone else { return }
        
        self.isGone = false
        // Restore size constraints to original constant.
        _ = self.findHeightConstraints()?.map { $0.setVisibleConstant() }
        _ = self.findWidthConstraints()?.map { $0.setVisibleConstant() }
        
        // Restore space constraints to original constant.
        _ = [.top, .bottom, .leading, .trailing].map { self.visibleSpacing($0) }

        // Reactivate other constraints.
        _ = self.aspectRatioConstraints?.map { $0.isActive = true }
        _ = self.equalWidthConstraints?.map { $0.isActive = true }
        _ = self.equalHeightConstraints?.map { $0.isActive = true }
        
        self.setNeedsUpdateConstraints()
        
        completion?()
    }
    
    private func goneSpacing(_ attribute: NSLayoutAttribute) {
        guard let spacingConstraints = self.findSpacingConstraints(itemView: self, attribute: attribute) else { return }
        _ = spacingConstraints.map { $0.setGoneConstant() }
    }
    
    private func visibleSpacing(_ attribute: NSLayoutAttribute) {
        guard let spacingConstraints = self.findSpacingConstraints(itemView: self, attribute: attribute) else { return }
        _ = spacingConstraints.map { $0.setVisibleConstant() }
    }

    // MARK: - Find Constraints
    
    private func findHeightConstraints() -> [NSLayoutConstraint]? {
        let heightConstraints = self.constraints.filter { $0.isHeight() }
        return heightConstraints.count > 0 ? heightConstraints : nil
    }
    
    private func findWidthConstraints() -> [NSLayoutConstraint]? {
        let widthConstraints = self.constraints.filter { $0.isWidth() }
        return widthConstraints.count > 0 ? widthConstraints : nil
    }
    
    private func findAspectRatioConstraints() -> [NSLayoutConstraint]? {
        return self.constraints.filter { $0.isAspectRatio() }
    }

    private func findSpacingConstraints(itemView: UIView, attribute: NSLayoutAttribute) -> [NSLayoutConstraint]? {
        guard let superview = self.superview else { return nil }
        let spacingConstraints = superview.constraints.filter { $0.isSpacing(itemView: itemView, attribute: attribute) }
        if spacingConstraints.count > 0 {
            return spacingConstraints
        } else {
            return superview.findSpacingConstraints(itemView: itemView, attribute: attribute)
        }
    }
    
    private func findEqualConstraints(itemView: UIView, attribute: NSLayoutAttribute) -> [NSLayoutConstraint]? {
        guard let superview = self.superview else { return nil }
        let equalConstraints = superview.constraints.filter { $0.isEqual(itemView: itemView, attribute: attribute) }
        if equalConstraints.count > 0 {
            return equalConstraints
        } else {
            return superview.findEqualConstraints(itemView: itemView, attribute: attribute)
        }
    }
    
    // MARK: - Add Size Constraint
    
    @discardableResult
    private func addHeightConstraint() -> NSLayoutConstraint {
        return self.addConstraint(attribute: .height, constant: self.bounds.size.height)
    }
    
    @discardableResult
    private func addWidthConstraint() -> NSLayoutConstraint {
        return self.addConstraint(attribute: .width, constant: self.bounds.size.width)
    }
    
    @discardableResult
    private func addConstraint(attribute: NSLayoutAttribute, constant: CGFloat) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(item: self, attribute: attribute, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: constant)
        constraint.priority = UILayoutPriorityDefaultHigh
        self.addConstraint(constraint)
        return constraint
    }
    
}