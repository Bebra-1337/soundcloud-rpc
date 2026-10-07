#pragma once

#include <QAbstractListModel>
#include <QElapsedTimer>
#include <QQmlParserStatus>
#include <QVariantMap>

// A list of items (see sc::item) from one api-v2 collection endpoint, loaded page by page through next_href
// as the view scrolls (canFetchMore/fetchMore). Also usable as a plain list via setItems().
class PagedListModel : public QAbstractListModel, public QQmlParserStatus
{
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(QVariantMap query READ query WRITE setQuery NOTIFY queryChanged)
    Q_PROPERTY(int pageSize READ pageSize WRITE setPageSize NOTIFY pageSizeChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool loaded READ loaded NOTIFY loadingChanged)
    Q_PROPERTY(bool hasMore READ hasMore NOTIFY loadingChanged)
    Q_PROPERTY(QString error READ error NOTIFY loadingChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles { ItemRole = Qt::UserRole + 1, KindRole };

    explicit PagedListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    bool canFetchMore(const QModelIndex &parent) const override;
    void fetchMore(const QModelIndex &parent) override;

    void classBegin() override {}
    void componentComplete() override;

    QString path() const { return m_path; }
    void setPath(const QString &path);
    QVariantMap query() const { return m_query; }
    void setQuery(const QVariantMap &query);
    int pageSize() const { return m_pageSize; }
    void setPageSize(int size);
    bool loading() const { return m_loading; }
    bool loaded() const { return m_loaded; }
    bool hasMore() const { return !m_next.isEmpty(); }
    QString error() const { return m_error; }
    int count() const { return m_items.size(); }

    Q_INVOKABLE void reload();
    Q_INVOKABLE void loadMore();
    Q_INVOKABLE QVariantList items() const { return m_items; }
    Q_INVOKABLE QVariantMap get(int row) const { return m_items.value(row).toMap(); }
    Q_INVOKABLE void setItems(const QVariantList &items);
    // Reload the first page but keep showing the current items until it arrives (no empty flash).
    Q_INVOKABLE void refresh();
    // loaded longer ago than this (or never)
    Q_INVOKABLE bool isStale(int ms) const;
    // local edits, e.g. a like/unlike made here, so the list doesn't need a reload
    Q_INVOKABLE void prepend(const QVariantMap &item);
    Q_INVOKABLE void removeById(const QVariant &id);

signals:
    void pathChanged();
    void queryChanged();
    void pageSizeChanged();
    void loadingChanged();
    void countChanged();

private:
    void request(const QString &pathOrUrl, bool first, bool replace = false);
    void maybeLoad();

    QString m_path;
    QVariantMap m_query;
    int m_pageSize = 30;
    QVariantList m_items;
    QString m_next;
    QString m_error;
    bool m_loading = false;
    bool m_loaded = false;
    bool m_complete = false;
    int m_generation = 0;
    QElapsedTimer m_loadedClock;
};
