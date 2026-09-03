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
    tableBody.innerHTML = '<tr><td colspan="7" class="text-center">Dükkanlar yükleniyor...</td></tr>';

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
        tableBody.innerHTML = '<tr><td colspan="7" class="text-center">Henüz kayıtlı bir dükkan bulunmuyor.</td></tr>';
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
            throw new Error(data.message || 'Dükkan oluşturulamadı.');
        }

        closeNewShopModal();
        showToast('Dükkan ve sahip hesabı başarıyla oluşturuldu!');
        loadShops();
    } catch (err) {
        alert('Hata: ' + err.message);
    }
}

async function toggleShopStatus(shopId, currentStatus) {
    const nextStatus = parseInt(currentStatus) === 1 ? 0 : 1;
    const confirmMsg = nextStatus === 0 
        ? 'Bu dükkanı dondurmak istediğinize emin misiniz? (Dükkan sahibi ve müşterileri giriş yapamaz)'
        : 'Bu dükkanı aktifleştirmek istediğinize emin misiniz?';

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

        showToast('Dükkan durumu güncellendi.');
        loadShops();
    } catch (err) {
        alert('Hata: ' + err.message);
    }
}

async function deleteShop(shopId, shopName) {
    if (!confirm(`"${shopName}" dükkanını ve ona bağlı TÜM ürün, müşteri ve siparişleri silmek istediğinize emin misiniz? Bu işlem geri alınamaz!`)) {
        return;
    }

    try {
        const res = await fetch(`${API_BASE}/superadmin/shops.php?id=${shopId}`, {
            method: 'DELETE',
            headers: { 'Authorization': `Bearer ${superAdminToken}` }
        });

        const data = await res.json();
        if (!res.ok || !data.success) throw new Error(data.message);

        showToast('Dükkan başarıyla silindi.');
        loadShops();
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
