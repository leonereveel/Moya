import Foundation
import RxSwift
import Result

/// Subclass of MoyaProvider that returns Observable instances when requests are made. Much better than using completion closures.
public class RxMoyaProvider<Target where Target: TargetType>: MoyaProvider<Target> {
    /// Initializes a reactive provider.
    override public init(endpointClosure: EndpointClosure = MoyaProvider.DefaultEndpointMapping,
        requestClosure: RequestClosure = MoyaProvider.DefaultRequestMapping,
        stubClosure: StubClosure = MoyaProvider.NeverStub,
        manager: Manager = RxMoyaProvider<Target>.DefaultAlamofireManager(),
        plugins: [PluginType] = [],
        trackInflights:Bool = false) {
            super.init(endpointClosure: endpointClosure, requestClosure: requestClosure, stubClosure: stubClosure, manager: manager, plugins: plugins, trackInflights: trackInflights)
    }

    /// Designated request-making method.
    public func request(token: Target) -> Observable<Response> {

        // Creates an observable that starts a request each time it's subscribed to.
        return Observable.create { [weak self] observer in
            let cancellableToken = self?.request(token) { result in
                switch result {
                case let .Success(response):
                    observer.onNext(response)
                    observer.onCompleted()
                    break
                case let .Failure(error):
                    observer.onError(error)
                }
            }

            return AnonymousDisposable {
                cancellableToken?.cancel()
            }
        }
    }
}

public extension RxMoyaProvider where Target:MultipartTargetType {
    public func request(token: Target) -> Observable<Progress> {
        let progressBlock = { (observer:AnyObserver) -> (Progress) -> Void in
            return { (progress:Progress) in
                observer.onNext(progress)
            }
        }
        
        let response:Observable<Progress> = Observable.create { [weak self] observer in
            let cancellableToken = self?.request(token, progress:progressBlock(observer)){ result in
                switch result {
                case let .Success(response):
                    observer.onNext(Progress(response:response))
                    observer.onCompleted()
                    break
                case let .Failure(error):
                    observer.onError(error)
                }
            }
            
            return AnonymousDisposable {
                cancellableToken?.cancel()
            }
        }.scan(Progress()) { (acc, curr) -> Progress in
            let totalBytes = curr.totalBytes > 0 ? curr.totalBytes : acc.totalBytes
            let bytesExpected = curr.bytesExpected > 0 ? curr.bytesExpected : acc.bytesExpected
            let response = curr.response ?? acc.response
            return Progress(totalBytes: totalBytes, bytesExpected: bytesExpected, response: response)
        }
        
        return (progress:progressSubject, response: response)
    }
}
