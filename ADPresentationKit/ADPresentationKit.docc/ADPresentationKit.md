# ``ADPresentationKit``

``ADPresentationKit`` provides custom presentation animation.

## Overview

A sample for using the presentation: 

```
guard let vc = storyboard?.instantiateViewController(withIdentifier: "SomeViewController") else { return }
let pm = SlidePresentationManager()
vc.modalPresentationStyle = .custom
vc.transitioningDelegate = pm
pmRef = pm // Keep a strong reference to the presentation manager 
present(vc, animated: true, completion: nil)
```

## Topics

### TODO: Group

- TODO: ``Symbol``
