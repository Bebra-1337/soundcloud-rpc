#include "models/PagedListModel.h"

#include "api/Entities.h"
#include "api/SoundCloudApi.h"

#include <QJsonArray>

PagedListModel::PagedListModel(QObject *parent) : QAbstractListModel(parent)
{
    // pages created before sign-in finished load once the API is ready
    if (auto *api = SoundCloudApi::instance())
        connect(api, &SoundCloudApi::readyChanged, this, &PagedListModel::maybeLoad);
}

int PagedListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_items.size());
}

QVariant PagedListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_items.size())
        return {};
    const QVariantMap item = m_items.at(index.row()).toMap();
    switch (role) {
    case ItemRole:
        return item;
    case KindRole:
        return item.value(QStringLiteral("kind"));
    }
    return {};
}

QHash<int, QByteArray> PagedListModel::roleNames() const
{
    return {{ItemRole, "item"}, {KindRole, "kind"}};
}

bool PagedListModel::canFetchMore(const QModelIndex &parent) const
{
    return !parent.isValid() && !m_loading && !m_next.isEmpty();
}

void PagedListModel::fetchMore(const QModelIndex &parent)
{
    if (!parent.isValid())
        loadMore();
}

void PagedListModel::componentComplete()
{
    m_complete = true;
    maybeLoad();
}

void PagedListModel::setPath(const QString &path)
{
    if (path == m_path)
        return;
    m_path = path;
    emit pathChanged();
    if (m_complete)
        reload();
}

void PagedListModel::setQuery(const QVariantMap &query)
{
    if (query == m_query)
        return;
    m_query = query;
    emit queryChanged();
    if (m_complete)
        reload();
}

void PagedListModel::setPageSize(int size)
{
    if (size == m_pageSize)
        return;
    m_pageSize = size;
    emit pageSizeChanged();
}

void PagedListModel::maybeLoad()
{
    auto *api = SoundCloudApi::instance();
    if (m_complete && !m_loaded && !m_loading && !m_path.isEmpty() && api && api->ready())
        reload();
}

void PagedListModel::reload()
{
    ++m_generation;
    beginResetModel();
    m_items.clear();
    endResetModel();
    emit countChanged();
    m_next.clear();
    m_loaded = false;
    m_error.clear();
    if (m_path.isEmpty()) {
        m_loading = false;
        emit loadingChanged();
        return;
    }
    request(m_path, true);
}

void PagedListModel::loadMore()
{
    if (!m_loading && !m_next.isEmpty())
        request(m_next, false);
}

void PagedListModel::setItems(const QVariantList &items)
{
    ++m_generation;
    beginResetModel();
    m_items = items;
    endResetModel();
    m_next.clear();
    m_loaded = true;
    m_loading = false;
    emit countChanged();
    emit loadingChanged();
}

void PagedListModel::refresh()
{
    if (m_path.isEmpty() || m_loading)
        return;
    ++m_generation;
    m_next.clear();
    m_error.clear();
    request(m_path, true, true);
}

bool PagedListModel::isStale(int ms) const
{
    return !m_loadedClock.isValid() || m_loadedClock.elapsed() > ms;
}

static int indexOfId(const QVariantList &items, const QVariant &id)
{
    for (int i = 0; i < items.size(); ++i) {
        if (items.at(i).toMap().value(QStringLiteral("id")).toLongLong() == id.toLongLong())
            return i;
    }
    return -1;
}

void PagedListModel::prepend(const QVariantMap &item)
{
    removeById(item.value(QStringLiteral("id")));
    beginInsertRows({}, 0, 0);
    m_items.prepend(item);
    endInsertRows();
    emit countChanged();
}

void PagedListModel::removeById(const QVariant &id)
{
    const int i = indexOfId(m_items, id);
    if (i < 0)
        return;
    beginRemoveRows({}, i, i);
    m_items.removeAt(i);
    endRemoveRows();
    emit countChanged();
}

void PagedListModel::request(const QString &pathOrUrl, bool first, bool replace)
{
    auto *api = SoundCloudApi::instance();
    if (!api || !api->ready())
        return;  // maybeLoad() runs again on readyChanged
    m_loading = true;
    emit loadingChanged();

    QUrlQuery q;
    if (first) {
        for (auto it = m_query.begin(); it != m_query.end(); ++it)
            q.addQueryItem(it.key(), it.value().toString());
        if (!m_query.contains(QStringLiteral("limit")))
            q.addQueryItem(QStringLiteral("limit"), QString::number(m_pageSize));
        q.addQueryItem(QStringLiteral("linked_partitioning"), QStringLiteral("1"));
    }
    const int generation = m_generation;
    api->get(pathOrUrl, q, this, [this, generation, first, replace](const QJsonDocument &doc) {
        if (generation != m_generation)
            return;
        const QJsonArray arr = doc.isArray() ? doc.array() : doc.object().value(QLatin1StringView("collection")).toArray();
        QVariantList page;
        for (const QJsonValue &v : arr) {
            QVariantMap m = sc::item(v.toObject());
            if (!m.isEmpty())
                page.append(m);
        }
        m_next = doc.object().value(QLatin1StringView("next_href")).toString();
        if (first)
            m_loadedClock.start();
        if (replace) {
            beginResetModel();
            m_items.clear();
            endResetModel();
            emit countChanged();
        }
        if (!page.isEmpty()) {
            const int first = int(m_items.size());
            beginInsertRows({}, first, int(first + page.size() - 1));
            m_items += page;
            endInsertRows();
            emit countChanged();
            SoundCloudApi::instance()->resolveArtwork(page, this, [this, generation, first](int i, const QVariantMap &item) {
                if (generation != m_generation || first + i >= m_items.size())
                    return;
                m_items[first + i] = item;
                emit dataChanged(index(first + i), index(first + i));
            });
        }
        m_loading = false;
        m_loaded = true;
        emit loadingChanged();
    }, [this, generation](int, const QString &err) {
        if (generation != m_generation)
            return;
        m_error = err;
        m_next.clear();
        m_loading = false;
        m_loaded = true;
        emit loadingChanged();
    });
}
