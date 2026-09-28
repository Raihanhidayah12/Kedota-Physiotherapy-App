import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private let privacyCoverTag = 847201

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)

    guard let window = window, window.viewWithTag(privacyCoverTag) == nil else {
      return
    }

    // Cover Flutter content before UIKit captures the app switcher preview.
    let cover = UIView(frame: window.bounds)
    cover.tag = privacyCoverTag
    cover.backgroundColor = UIColor(red: 0.96, green: 0.98, blue: 0.98, alpha: 1)
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    let label = UILabel()
    label.text = "Kedota Physiotherapy"
    label.textColor = UIColor(red: 0, green: 0.50, blue: 0.47, alpha: 1)
    label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
    label.translatesAutoresizingMaskIntoConstraints = false
    cover.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: cover.centerYAnchor),
    ])

    window.addSubview(cover)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    window?.viewWithTag(privacyCoverTag)?.removeFromSuperview()
  }
}
