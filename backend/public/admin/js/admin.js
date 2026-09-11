// backend/public/admin/js/admin.js

const API_BASE = window.location.origin.includes('localhost') || window.location.origin.includes('127.0.0.1')
    ? window.location.origin + '/backend/api'
    : '/backend/api';

let superAdminToken = localStorage.getItem('super_admin_token') || null;

document.addEventListener('DOMContentLoaded', () => {
    if (superAdminToken) {
        checkSession();
    } else {
        showLogin();
    }
});

function showToast(message, isError = false) {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.style.borderColor = isError ? 'var(--danger)' : 'var(--success)';
    toast.style.display = 'block';
    setTimeout(() => {
        toast.style.display = 'none';
    }, 3500);
}

function showLogin() {
    document.getElementById('loginSection').style.display = 'flex';
    document.getElementById('dashboardSection').style.display = 'none';
}

function showDashboard() {
    document.getElementById('loginSection').style.display = 'none';
    document.getElementById('dashboardSection').style.display = 'flex';
    loadShops();
}

async function handleSuperAdminLogin(e) {
    e.preventDefault();
    const username = document.getElementById('adminUsername').value.trim();
    const password = document.getElementById('adminPassword').value.trim();
    const errBox = document.getElementById('loginError');

    errBox.style.display = 'none';

    try {
        const res = await fetch(`${API_BASE}/auth/login.php`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username, password })
        });

        const data = await res.json();

        if (!res.ok || !data.success) {
            throw new Error(data.message || 'Giriş başarısız.');
        }

        if (data.data.user.role !== 'SUPER_ADMIN') {
            throw new Error('Bu panele yalnızca Süper Admin kullanıcıları erişebilir!');
        }

        superAdminToken = data.data.token;
        localStorage.setItem('super_admin_token', superAdminToken);
        localStorage.setItem('super_admin_user', JSON.stringify(data.data.user));

        updateAdminInfo(data.data.user);
        showDashboard();
        showToast('Sisteme hoş geldiniz, Süper Admin.');
    } catch (err) {
        errBox.textContent = err.message;
        errBox.style.display = 'block';
    }
}

function updateAdminInfo(user) {
    if (!user) return;
    document.getElementById('currentAdminName').textContent = user.full_name || 'Sistem Yöneticisi';
    document.getElementById('currentAdminUsername').textContent = '@' + (user.username || 'admin');
    document.getElementById('currentAdminNameInitial').textContent = (user.full_name || 'A')[0].toUpperCase();
}

function handleLogout() {
    localStorage.removeItem('super_admin_token');
    localStorage.removeItem('super_admin_user');
    superAdminToken = null;
    showLogin();
    showToast('Oturum kapatıldı.');
}

async function checkSession() {
    const user = JSON.parse(localStorage.getItem('super_admin_user') || '{}');
    updateAdminInfo(user);
    showDashboard();
}

async function loadShops() {
    const tableBody = document.getElementById('shopsTableBody');
    tableBody.innerHTML = '<tr><td colspan="7" class="text-center">İşletmeler yükleniyor...</td></tr>';

    try {
        const res = await fetch(`${API_BASE}/superadmin/shops.php`, {
            headers: { 'Authorization': `Bearer ${superAdminToken}` }
        });

        const data = await res.json();

        if (res.status === 401 || res.status === 403) {
            handleLogout();
            return;
        }

        if (!data.success) {
            throw new Error(data.message);
        }

        const shops = data.data || [];
        renderShops(shops);
        updateStats(shops);
    } catch (err) {
        tableBody.innerHTML = `<tr><td colspan="7" style="color:var(--danger); text-align:center;">Hata: ${err.message}</td></tr>`;
    }
}

function updateStats(shops) {
    document.getElementById('statTotalShops').textContent = shops.length;
    let totalProds = 0, totalCusts = 0, totalOrds = 0;
    shops.forEach(s => {
        totalProds += parseInt(s.product_count || 0);
        totalCusts += parseInt(s.customer_count || 0);
        totalOrds += parseInt(s.order_count || 0);
    });
    document.getElementById('statTotalProducts').textContent = totalProds;
    document.getElementById('statTotalCustomers').textContent = totalCusts;
    document.getElementById('statTotalOrders').textContent = totalOrds;
}

function renderShops(shops) {
    const tableBody = document.getElementById('shopsTableBody');
    if (shops.length === 0) {
        tableBody.innerHTML = '<tr><td colspan="7" class="text-center">Henüz kayıtlı bir işletme bulunmuyor.</td></tr>';
        return;
    }

    tableBody.innerHTML = shops.map(s => `
        <tr>
            <td>#${s.id}</td>
            <td><strong>${escapeHtml(s.name)}</strong><br><small style="color:var(--text-muted)">${escapeHtml(s.address || 'Adres yok')}</small></td>
            <td>${escapeHtml(s.owner_name || 'Sahipsiz')}<br><small style="color:var(--text-muted)">@${escapeHtml(s.owner_username || '-')}</small></td>
            <td>${escapeHtml(s.phone || '-')}</td>
            <td>
                <span title="Ürün">🍔 ${s.product_count}</span> &nbsp;|&nbsp; 
                <span title="Müşteri">👥 ${s.customer_count}</span> &nbsp;|&nbsp; 
                <span title="Sipariş">📦 ${s.order_count}</span>
            </td>
            <td>
                <span class="status-badge ${parseInt(s.is_active) === 1 ? 'status-active' : 'status-passive'}">
                    ${parseInt(s.is_active) === 1 ? 'Aktif' : 'Donduruldu'}
                </span>
            </td>
            <td>
                <div class="action-buttons">
                    <button onclick="toggleShopStatus(${s.id}, ${s.is_active})" class="btn-action btn-toggle">
                        ${parseInt(s.is_active) === 1 ? 'Dondur' : 'Aktifleştir'}
                    </button>
                    <button onclick="deleteShop(${s.id}, '${escapeHtml(s.name)}')" class="btn-action btn-delete">
                        Sil
                    </button>
                </div>
            </td>
        </tr>
    `).join('');
}

function openNewShopModal() {
    document.getElementById('newShopForm').reset();
    document.getElementById('newShopModal').style.display = 'flex';
}

function closeNewShopModal() {
    document.getElementById('newShopModal').style.display = 'none';
}

async function handleCreateShop(e) {
    e.preventDefault();
    const payload = {
        shop_name: document.getElementById('shopName').value.trim(),
        shop_phone: document.getElementById('shopPhone').value.trim(),
        shop_address: document.getElementById('shopAddress').value.trim(),
        owner_fullname: document.getElementById('ownerFullName').value.trim(),
        owner_username: document.getElementById('ownerUsername').value.trim(),
        owner_password: document.getElementById('ownerPassword').value.trim()
    };

    try {
        const res = await fetch(`${API_BASE}/superadmin/shops.php`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${superAdminToken}`
            },
            body: JSON.stringify(payload)
        });

        const data = await res.json();
        if (!res.ok || !data.success) {
            throw new Error(data.message || 'İşletme oluşturulamadı.');
        }

        closeNewShopModal();
        showToast('İşletme ve sahip hesabı başarıyla oluşturuldu!');
        loadShops();
    } catch (err) {
        alert('Hata: ' + err.message);
    }
}

async function toggleShopStatus(shopId, currentStatus) {
    const nextStatus = parseInt(currentStatus) === 1 ? 0 : 1;
    const confirmMsg = nextStatus === 0 
        ? 'Bu işletmeyi dondurmak istediğinize emin misiniz? (İşletme sahibi ve müşterileri giriş yapamaz)'
        : 'Bu işletmeyi aktifleştirmek istediğinize emin misiniz?';

    if (!confirm(confirmMsg)) return;

    try {
        const res = await fetch(`${API_BASE}/superadmin/shops.php`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${superAdminToken}`
            },
            body: JSON.stringify({ id: shopId, is_active: nextStatus })
        });

        const data = await res.json();
        if (!res.ok || !data.success) throw new Error(data.message);

        showToast('İşletme durumu güncellendi.');
        loadShops();
    } catch (err) {
        alert('Hata: ' + err.message);
    }
}

async function deleteShop(shopId, shopName) {
    if (!confirm(`"${shopName}" işletmesini ve ona bağlı TÜM ürün, müşteri ve siparişleri silmek istediğinize emin misiniz? Bu işlem geri alınamaz!`)) {
        return;
    }

    try {
        const res = await fetch(`${API_BASE}/superadmin/shops.php?id=${shopId}`, {
            method: 'DELETE',
            headers: { 'Authorization': `Bearer ${superAdminToken}` }
        });

        const data = await res.json();
        if (!res.ok || !data.success) throw new Error(data.message);

        showToast('İşletme başarıyla silindi.');
        loadShops();
    } catch (err) {
        alert('Hata: ' + err.message);
    }
}

function switchTab(tab) {
    const navShops = document.getElementById('navShops');
    const navAnnouncements = document.getElementById('navAnnouncements');
    const shopsView = document.getElementById('shopsTabView');
    const announcementsView = document.getElementById('announcementsTabView');

    if (tab === 'shops') {
        navShops.classList.add('active');
        navAnnouncements.classList.remove('active');
        shopsView.style.display = 'block';
        announcementsView.style.display = 'none';
        loadShops();
    } else if (tab === 'announcements') {
        navShops.classList.remove('active');
        navAnnouncements.classList.add('active');
        shopsView.style.display = 'none';
        announcementsView.style.display = 'block';
        loadAnnouncements();
    }
}

function openNewAnnouncementModal() {
    document.getElementById('newAnnouncementForm').reset();
    document.getElementById('newAnnouncementModal').style.display = 'flex';
}

function closeNewAnnouncementModal() {
    document.getElementById('newAnnouncementModal').style.display = 'none';
}

async function loadAnnouncements() {
    const tableBody = document.getElementById('announcementsTableBody');
    tableBody.innerHTML = '<tr><td colspan="7" class="text-center">Duyurular yükleniyor...</td></tr>';

    try {
        const res = await fetch(`${API_BASE}/superadmin/announcements.php`, {
            headers: { 'Authorization': `Bearer ${superAdminToken}` }
        });

        const data = await res.json();

        if (res.status === 401 || res.status === 403) {
            handleLogout();
            return;
        }

        if (!data.success) {
            throw new Error(data.message);
        }

        const list = data.data || [];
        renderAnnouncements(list);
    } catch (err) {
        tableBody.innerHTML = `<tr><td colspan="7" style="color:var(--danger); text-align:center;">Hata: ${err.message}</td></tr>`;
    }
}

function renderAnnouncements(list) {
    const tableBody = document.getElementById('announcementsTableBody');
    if (list.length === 0) {
        tableBody.innerHTML = '<tr><td colspan="7" class="text-center">Henüz yayınlanmış bir duyuru yok.</td></tr>';
        return;
    }

    tableBody.innerHTML = list.map(a => {
        let targetBadge = '<span class="badge badge-primary">🏪 İşletme Sahipleri</span>';
        if (a.target_role === 'ALL') targetBadge = '<span class="badge badge-success">🌐 Herkes</span>';
        if (a.target_role === 'CUSTOMER') targetBadge = '<span class="badge badge-warning">👥 Müşteriler</span>';

        return `
            <tr>
                <td>#${a.id}</td>
                <td><strong>${escapeHtml(a.title)}</strong></td>
                <td style="max-width: 300px; white-space: pre-wrap; color: var(--text-muted); font-size: 13px;">${escapeHtml(a.content)}</td>
                <td>${targetBadge}</td>
                <td><small style="color:var(--text-muted)">${new Date(a.created_at).toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' })}</small></td>
                <td>
                    <span class="status-indicator ${parseInt(a.is_active) === 1 ? 'status-active' : 'status-inactive'}">
                        ${parseInt(a.is_active) === 1 ? 'Yayında' : 'Pasif'}
                    </span>
                </td>
                <td>
                    <button onclick="deleteAnnouncement(${a.id}, '${escapeHtml(a.title)}')" class="btn-action btn-danger" title="Duyuruyu Sil">
                        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
                        Sil
                    </button>
                </td>
            </tr>
        `;
    }).join('');
}

async function handleCreateAnnouncement(e) {
    e.preventDefault();
    const title = document.getElementById('announcementTitle').value.trim();
    const target_role = document.getElementById('announcementTarget').value;
    const content = document.getElementById('announcementContent').value.trim();

    try {
        const res = await fetch(`${API_BASE}/superadmin/announcements.php`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${superAdminToken}`
            },
            body: JSON.stringify({ title, target_role, content, is_active: 1 })
        });

        const data = await res.json();
        if (!res.ok || !data.success) {
            throw new Error(data.message || 'Duyuru yayınlanamadı.');
        }

        closeNewAnnouncementModal();
        showToast('Duyuru tüm işletme sahiplerine başarıyla iletildi!');
        loadAnnouncements();
    } catch (err) {
        alert('Hata: ' + err.message);
    }
}

async function deleteAnnouncement(id, title) {
    if (!confirm(`"${title}" başlıklı duyuruyu silmek istediğinize emin misiniz?`)) {
        return;
    }

    try {
        const res = await fetch(`${API_BASE}/superadmin/announcements.php?id=${id}`, {
            method: 'DELETE',
            headers: { 'Authorization': `Bearer ${superAdminToken}` }
        });

        const data = await res.json();
        if (!res.ok || !data.success) throw new Error(data.message);

        showToast('Duyuru yayından kaldırıldı ve silindi.');
        loadAnnouncements();
    } catch (err) {
        alert('Hata: ' + err.message);
    }
}

function escapeHtml(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}
