// Copyright © 2020 Metabolist. All rights reserved.

import Combine
import DB
import Foundation
import Mastodon
import MastodonAPI

public struct SearchService {
    public let sections: AnyPublisher<[CollectionSection], Error>
    public let navigationService: NavigationService
    public let nextPageMaxId: AnyPublisher<String, Never>

    private let mastodonAPIClient: MastodonAPIClient
    private let contentDatabase: ContentDatabase
    private let nextPageMaxIdSubject = PassthroughSubject<String, Never>()
    private let resultsSubject = PassthroughSubject<(Results, Search), Error>()

    init(mastodonAPIClient: MastodonAPIClient, contentDatabase: ContentDatabase) {
        self.mastodonAPIClient = mastodonAPIClient
        self.contentDatabase = contentDatabase
        nextPageMaxId = nextPageMaxIdSubject.eraseToAnyPublisher()
        navigationService = NavigationService(mastodonAPIClient: mastodonAPIClient, contentDatabase: contentDatabase)
        sections = resultsSubject.scan(.empty) {
            let (results, search) = $1

            return search.offset == nil ? results : $0.appending(results)
        }
        .flatMap(contentDatabase.publisher(results:)).eraseToAnyPublisher()
    }
}

extension SearchService: CollectionService {
    public func request(maxId: String?, minId: String?, search: Search?) -> AnyPublisher<Never, Error> {
        guard let search = search else { return Empty().eraseToAnyPublisher() }

        return mastodonAPIClient.request(ResultsEndpoint.search(search))
            .handleEvents(receiveOutput: { resultsSubject.send(($0, search)) })
            .flatMap(contentDatabase.insert(results:))
            .eraseToAnyPublisher()
    }
}
