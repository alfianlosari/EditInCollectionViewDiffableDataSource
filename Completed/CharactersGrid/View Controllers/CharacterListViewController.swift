//
//  CharacterListViewController.swift
//  CharactersGrid
//
//  Created by Alfian Losari on 10/11/20.
//

import Combine
import SwiftUI
import UIKit

class CharacterListViewController: UIViewController {
    
    private var collectionView: UICollectionView!
    private var segmentedControl = UISegmentedControl(
        items: Universe.allCases.map { $0.title }
    )
    
    var backingStore: [SectionCharactersTuple]
    private var dataSource: UICollectionViewDiffableDataSource<Section, Character>!
    private var selectedCharacters = Set<Character>()
    
    private var searchTextSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    private var cellRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, Character>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!
    
    private lazy var listLayout: UICollectionViewLayout = {
        var listConfig = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        listConfig.headerMode = .supplementary
        listConfig.trailingSwipeActionsConfigurationProvider = { indexPath -> UISwipeActionsConfiguration? in
            guard let character = self.dataSource.itemIdentifier(for: indexPath) else {
                return nil
            }
            return UISwipeActionsConfiguration(
                actions: [
                    UIContextualAction(
                        style: .destructive,
                        title: "Delete",
                        handler: { [weak self] (_, _, completion) in
                            self?.deleteCharacter(character)
                            completion(true)
                        })
                ]
            )
        }
        return UICollectionViewCompositionalLayout.list(using: listConfig)
    }()
        
    init(sectionedCharacters: [SectionCharactersTuple] = Universe.ff7r.sectionedStubs) {
        self.backingStore = sectionedCharacters
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupSegmentedControl()
        setupBaritems()
        setupSearchBar()
        setupSearchTextObserver()
        setupDataSource()
        setupSnapshot(store: backingStore)
    }
    
    private func setupSearchBar() {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController
    }
    
    private func setupSegmentedControl() {
        segmentedControl.selectedSegmentIndex = 0
        navigationItem.titleView = segmentedControl
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
    }
    
    private func setupBaritems() {
        navigationItem.leftBarButtonItem = editButtonItem
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "shuffle"), style: .plain, target: self, action: #selector(shuffleTapped)),
            UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise.circle"), style: .plain, target: self, action: #selector(resetTapped))
        ]
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        collectionView.isEditing = editing
    }
    
    private func setupCollectionView() {
        collectionView = .init(frame: view.bounds, collectionViewLayout: listLayout)
        collectionView.backgroundColor = .systemBackground
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(collectionView)
        
        cellRegistration = UICollectionView.CellRegistration(
            handler: { (cell: UICollectionViewListCell, _, character: Character) in
                var content = UIListContentConfiguration.valueCell()
                content.text = character.name
                content.secondaryText = character.job
                content.image = UIImage(named: character.imageName)
                content.imageProperties.maximumSize = .init(width: 24, height: 24)
                content.imageProperties.cornerRadius = 12
                cell.contentConfiguration = content
                
                var accessories: [UICellAccessory] = [
                    .delete(displayed: .whenEditing, actionHandler: { [weak self] in
                        self?.deleteCharacter(character)
                    }),
                    .reorder(displayed: .whenEditing)
                ]
                
                if self.selectedCharacters.contains(character) {
                    accessories.append(.checkmark(displayed: .whenNotEditing))
                }
                
                cell.accessories = accessories
            })
        
        headerRegistration = UICollectionView.SupplementaryRegistration(elementKind: UICollectionView.elementKindSectionHeader, handler: { [weak self](header: UICollectionViewListCell, _, indexPath) in
            self?.configureHeaderView(header, at: indexPath)
        })
        
        collectionView.delegate = self
    }
    
    private func deleteCharacter(_ character: Character) {
        guard let indexPath = dataSource.indexPath(for: character) else {
            return
        }
        
        backingStore[indexPath.section].characters.remove(at: indexPath.item)
        selectedCharacters.remove(character)
        
        var snapshot = dataSource.snapshot()
        snapshot.deleteItems([character])
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func setupDataSource() {
        dataSource = .init(collectionView: collectionView, cellProvider: { [weak self] (collectionView, indexPath, character) -> UICollectionViewCell? in
            guard let self = self else { return nil }
            let cell = collectionView.dequeueConfiguredReusableCell(using: self.cellRegistration, for: indexPath, item: character)
            return cell
        })
        
        dataSource.supplementaryViewProvider = { [weak self](collectionView, kind, indexPath) -> UICollectionReusableView in
            guard let self = self else { return UICollectionReusableView() }
            let headerView = collectionView.dequeueConfiguredReusableSupplementary(using: self.headerRegistration, for: indexPath)
            return headerView
        }
        
        dataSource.reorderingHandlers.canReorderItem = { character -> Bool in
            (self.navigationItem.searchController?.searchBar.text ?? "").isEmpty
        }
        
        dataSource.reorderingHandlers.didReorder = { transaction in
            var backingStore = self.backingStore
            for sectionTransaction in transaction.sectionTransactions {
                let sectionIdentifier = sectionTransaction.sectionIdentifier
                if let sectionIndex = transaction.finalSnapshot.indexOfSection(sectionIdentifier) {
                    backingStore[sectionIndex].characters = sectionTransaction.finalSnapshot.items
                }
            }
            self.backingStore = backingStore
            self.reloadHeaders()
        }
    }
    
    private func setupSnapshot(store: [SectionCharactersTuple]) {
        var snapshot = NSDiffableDataSourceSnapshot<CharactersGrid.Section, Character>()
        store.forEach { (sectionCharacters) in
            let (section, characters) = sectionCharacters
            snapshot.appendSections([section])
            snapshot.appendItems(characters, toSection: section)
        }
        dataSource.apply(snapshot, animatingDifferences: true, completion: reloadHeaders)
    }
    
    private func setupSearchTextObserver() {
        searchTextSubject
            .debounce(for: .seconds(0.1), scheduler: RunLoop.main)
            .map { $0.lowercased() }
            .sink { [weak self] (text) in
                guard let self = self else { return }
                if text.isEmpty {
                    self.setupSnapshot(store: self.backingStore)
                } else {
                    let searchStore = self.backingStore
                        .map {
                            ($0.section, $0.characters
                                .filter { $0.name.lowercased().contains(text) }
                            )
                        }.filter { !$0.1.isEmpty }
                    self.setupSnapshot(store: searchStore)
                }
            }
            .store(in: &cancellables)
    }
    
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        backingStore = sender.selectedUniverse.sectionedStubs
        setupSnapshot(store: backingStore)
    }
    
    @objc private func shuffleTapped(_ sender: Any) {
        self.backingStore = self.backingStore.shuffled().map { ($0.section, $0.characters.shuffled()) }
        setupSnapshot(store: backingStore)
    }
    
    @objc private func resetTapped(_ sender: Any) {
        backingStore = segmentedControl.selectedUniverse.sectionedStubs
        setupSnapshot(store: backingStore)
    }
    
    private func reloadHeaders() {
        collectionView.indexPathsForVisibleSupplementaryElements(ofKind: UICollectionView.elementKindSectionHeader).forEach { (indexPath) in
            guard let header = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPath) as? UICollectionViewListCell else {
                return
            }
            self.configureHeaderView(header, at: indexPath)
        }
    }
    
    private func configureHeaderView(_ headerView: UICollectionViewListCell, at indexPath: IndexPath) {
        guard
            let item = dataSource.itemIdentifier(for: indexPath),
            let section = dataSource.snapshot().sectionIdentifier(containingItem: item)
        else {
            return
        }
        let count = dataSource.snapshot().itemIdentifiers(inSection: section).count
        var content = headerView.defaultContentConfiguration()
        content.text = section.headerTitleText(count: count)
        headerView.contentConfiguration = content
    }
        
    required init?(coder: NSCoder) {
        fatalError("Please initialize programatically instead of using Storyboard/XiB")
    }

}

extension CharacterListViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let character = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        
        if selectedCharacters.contains(character) {
            selectedCharacters.remove(character)
        } else {
            selectedCharacters.insert(character)
        }
        
        var snapshot = dataSource.snapshot()
        snapshot.reloadItems([character])
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
}

extension CharacterListViewController: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        searchTextSubject.send(searchController.searchBar.text ?? "")
    }
    
}

struct CharacterListViewControllerRepresentable: UIViewControllerRepresentable {
    
    let sectionedCharacters: [SectionCharactersTuple]
    
    func makeUIViewController(context: Context) -> some UIViewController {
        UINavigationController(rootViewController: CharacterListViewController(sectionedCharacters: sectionedCharacters))
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
    
}

struct CharacterList_Previews: PreviewProvider {
    
    static var previews: some View {
        CharacterListViewControllerRepresentable(sectionedCharacters: Universe.ff7r.sectionedStubs)
            .edgesIgnoringSafeArea(.vertical)
    }
    
}
