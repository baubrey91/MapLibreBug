import Foundation
import UIKit

// MARK: - Models

// The direction to use for the diagonal stripe line
enum StripeDirection {
    case rightToLeft
    case leftToRight
}

/// View model for composing the StripedViewModel view content.
struct StripedViewModel {
    let lineGap: CGFloat
    let lineWidth: CGFloat
    let lineColor: UIColor?
    let backgroundColor: UIColor
    let lineColorAlpha: CGFloat
    let lineDirection: StripeDirection
    
    init(lineGap: CGFloat = 0.0,
         lineWidth: CGFloat = 0.0,
         lineColor: UIColor? = nil,
         backgroundColor: UIColor,
         lineDirection: StripeDirection = .leftToRight,
         lineColorAlpha: CGFloat = 1.0) {
        
        self.lineGap = lineGap
        self.lineWidth = lineWidth
        self.lineColor = lineColor?.withAlphaComponent(lineColorAlpha)
        self.backgroundColor = backgroundColor
        self.lineColorAlpha = lineColorAlpha
        self.lineDirection = lineDirection
    }
}

// MARK: Protocols
protocol StripedViewType {
    /// Will configure the view with the view model
    ///
    /// - Parameters:
    ///   - viewModel: the view model backing this striped view instance.
    func configure(viewModel: StripedViewModel)
}

class StripedView : UIView {

    // MARK: Properties
    private var viewModel: StripedViewModel?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let viewModel = self.viewModel,
            let linecolor = viewModel.lineColor else {
            return
        }
        
        let graphicsContext = UIGraphicsGetCurrentContext()
        
        if viewModel.lineDirection == .rightToLeft {
            // flip y-axis of context, so (0,0) is the bottom left of the context
            graphicsContext?.scaleBy(x: 1, y: -1)
            graphicsContext?.translateBy(x: 0, y: -bounds.size.height)
        }
        
        // generate a slightly larger rect than the view,
        // to allow the lines to appear seamless
        let renderRect = bounds.insetBy(dx: -viewModel.lineWidth * 0.5, dy: -viewModel.lineWidth * 0.5)
        
        // the total distance to travel when looping (each line starts at a point that
        // starts at (0,0) and ends up at (width, height)).
        let totalDistance = renderRect.size.width + renderRect.size.height
        
        // loop through distances in the range 0 ... totalDistance
        for distance in stride(from: 0, through: totalDistance,
            // divide by cos(45º) to convert from diagonal length
            by: (viewModel.lineGap + viewModel.lineWidth) / cos(.pi / 4)) {
                
                // the start of one of the stripes
                graphicsContext?.move(to: CGPoint(
                    // x-coordinate based on whether the distance is less than the width of the
                    // rect (it should be fixed if it is above, and moving if it is below)
                    x: distance < renderRect.width ?
                        renderRect.origin.x + distance :
                        renderRect.origin.x + renderRect.width,
                    
                    // y-coordinate based on whether the distance is less than the width of the
                    // rect (it should be moving if it is above, and fixed if below)
                    y: distance < renderRect.width ?
                        renderRect.origin.y :
                        distance - (renderRect.width - renderRect.origin.x)
                ))
                
                // the end of one of the stripes
                graphicsContext?.addLine(to: CGPoint(
                    // x-coordinate based on whether the distance is less than the height of
                    // the rect (it should be moving if it is above, and fixed if it is below)
                    x: distance < renderRect.height ?
                        renderRect.origin.x :
                        distance - (renderRect.height - renderRect.origin.y),
                    
                    // y-coordinate based on whether the distance is less than the height of
                    // the rect (it should be fixed if it is above, and moving if it is below)
                    y: distance < renderRect.height ?
                        renderRect.origin.y + distance :
                        renderRect.origin.y + renderRect.height
                ))
        }
        
        // stroke all of the lines added
        graphicsContext?.setStrokeColor(linecolor.cgColor)
        graphicsContext?.setLineWidth(viewModel.lineWidth)
        graphicsContext?.strokePath()
    }
}

// MARK: StripedViewType
extension StripedView: StripedViewType {
    func configure(viewModel: StripedViewModel) {
        self.viewModel = viewModel
        self.backgroundColor = viewModel.backgroundColor
    }
}

extension UIView {
    func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: self.bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
}
