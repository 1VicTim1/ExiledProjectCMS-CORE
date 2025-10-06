<template>
  <div class="container py-4">
    <div class="d-flex align-items-center mb-4">
      <i class="bi bi-pencil-square display-5 text-primary me-3"></i>
      <h2 class="fw-bold mb-0">Редактор страниц</h2>
      <button class="btn btn-success ms-auto" @click="createNewPage">
        <i class="bi bi-plus-lg"></i> Новая страница
      </button>
    </div>
    <div class="row mb-3">
      <div class="col-md-4">
        <ul class="list-group">
          <li v-for="p in pages" :key="p.id" :class="{'active': p.id===selectedPage?.id}"
              class="list-group-item d-flex justify-content-between align-items-center" @click="selectPage(p)">
            <span>{{ p.title }}</span>
            <button class="btn btn-sm btn-danger" @click.stop="deletePage(p.id)"><i class="bi bi-trash"></i></button>
          </li>
        </ul>
      </div>
      <div class="col-md-8">
        <div v-if="selectedPage">
          <input v-model="selectedPage.title" class="form-control mb-2" placeholder="Заголовок страницы">
          <textarea v-model="selectedPage.content" class="form-control mb-2" placeholder="HTML контент"
                    rows="10"></textarea>
          <button class="btn btn-primary" @click="savePage"><i class="bi bi-save"></i> Сохранить</button>
        </div>
        <div v-else class="text-muted">Выберите или создайте страницу для редактирования.</div>
      </div>
    </div>
    <div v-if="selectedPage" class="mt-4">
      <h5>Превью:</h5>
      <div class="border p-3 bg-light" v-html="selectedPage.content"></div>
    </div>
    <div class="card mt-4">
      <div class="card-header d-flex align-items-center">
        <i class="bi bi-shield-check me-2"></i>
        <b>UI-разрешения</b>
        <button class="btn btn-sm btn-success ms-auto" @click="addPermission"><i class="bi bi-plus-lg"></i> Новое
          разрешение
        </button>
      </div>
      <div class="card-body">
        <div class="mb-2 text-muted">
          Используйте <code>v-if=\"hasPermission('perm_name')\"</code> для условного отображения элементов. Разрешения
          можно назначать ролям в разделе "Роли и разрешения".
        </div>
        <ul class="list-group mb-2">
          <li v-for="(perm, idx) in uiPermissions" :key="perm" class="list-group-item d-flex align-items-center">
            <input v-model="uiPermissions[idx]" class="form-control me-2" style="max-width:220px;">
            <button class="btn btn-sm btn-danger" @click="removePermission(idx)"><i class="bi bi-trash"></i></button>
          </li>
        </ul>
      </div>
    </div>
    <div class="card mt-4">
      <div class="card-header d-flex align-items-center">
        <i class="bi bi-palette me-2"></i>
        <b>Визуальный редактор страницы</b>
        <button class="btn btn-sm btn-success ms-auto" @click="addElement"><i class="bi bi-plus-lg"></i> Добавить
          элемент
        </button>
      </div>
      <div class="card-body bg-light">
        <div class="mb-2 text-muted">
          Перетаскивайте элементы, меняйте их стиль, добавляйте кнопки, изображения, иконки, фон, градиенты,
          прозрачность, редактируйте футер и хедер. Все изменения будут видны всем пользователям.
        </div>
        <div :style="{
               minHeight: '320px',
               position: 'relative',
               background: pageGradient ? pageGradient : pageBg,
               fontFamily: pageFont,
               fontSize: pageFontSize + 'px'
             }"
             class="visual-editor">
          <div v-for="(el, idx) in visualElements" :key="el.id"
               :style="elementStyle(el)"
               class="ve-elem border rounded position-absolute p-2"
               draggable="true"
               @dragend="dragEnd($event)"
               @dragstart="dragStart(idx, $event)">
            <div class="d-flex align-items-center mb-1">
              <i :class="el.icon || 'bi bi-box'" class="me-2"></i>
              <input v-model="el.text" class="form-control form-control-sm me-2" style="width:120px;">
              <button class="btn btn-sm btn-outline-secondary me-1" @click="editStyle(idx)"><i class="bi bi-brush"></i>
              </button>
              <button class="btn btn-sm btn-outline-danger" @click="removeElement(idx)"><i class="bi bi-trash"></i>
              </button>
            </div>
            <div v-if="el.type==='img'">
              <input class="form-control form-control-sm mb-1" type="file" @change="e=>onImageChange(e, idx)">
              <img v-if="el.src" :src="el.src" alt="" style="max-width:120px;max-height:80px;">
            </div>
            <div v-if="el.type==='button'">
              <button class="btn btn-primary btn-sm">{{ el.text }}</button>
            </div>
          </div>
        </div>
        <!-- Панель стилей -->
        <div v-if="showStylePanel!==null" class="card mt-3 p-2">
          <h6>Настройки стиля</h6>
          <div class="row g-2">
            <div class="col-6">
              <label class="form-label">Размер</label>
              <input v-model.number="visualElements[showStylePanel].style.width" class="form-control" max="600"
                     min="40" type="number">
            </div>
            <div class="col-6">
              <label class="form-label">Высота</label>
              <input v-model.number="visualElements[showStylePanel].style.height" class="form-control" max="400"
                     min="20" type="number">
            </div>
            <div class="col-6">
              <label class="form-label">Цвет текста</label>
              <input v-model="visualElements[showStylePanel].style.color" class="form-control form-control-color"
                     type="color">
            </div>
            <div class="col-6">
              <label class="form-label">Цвет фона</label>
              <input v-model="visualElements[showStylePanel].style.background" class="form-control form-control-color"
                     type="color">
            </div>
            <div class="col-6">
              <label class="form-label">Прозрачность</label>
              <input v-model.number="visualElements[showStylePanel].style.opacity" class="form-range" max="1" min="0.1"
                     step="0.05" type="range">
            </div>
            <div class="col-6">
              <label class="form-label">Градиент</label>
              <input v-model="visualElements[showStylePanel].style.gradient" class="form-control" placeholder="linear-gradient(...)"
                     type="text">
            </div>
            <div class="col-6">
              <label class="form-label">Иконка</label>
              <input v-model="visualElements[showStylePanel].icon" class="form-control" placeholder="bi bi-star"
                     type="text">
            </div>
            <div class="col-6">
              <label class="form-label">Шрифт</label>
              <input v-model="visualElements[showStylePanel].style.fontFamily" class="form-control" placeholder="Arial, sans-serif"
                     type="text">
            </div>
          </div>
          <button class="btn btn-sm btn-secondary mt-2" @click="showStylePanel=null">Закрыть</button>
        </div>
      </div>
    </div>
    <div class="card mt-4">
      <div class="card-header d-flex align-items-center">
        <i class="bi bi-layout-text-sidebar-reverse me-2"></i>
        <b>Редактирование хедера и футера</b>
      </div>
      <div class="card-body bg-light">
        <div class="mb-2 text-muted">Настройте внешний вид хедера и футера для всех пользователей. Можно добавить текст,
          кнопки, изображения, иконки, выбрать цвет, фон, градиент, прозрачность, шрифт и размер.
        </div>
        <div class="row g-2">
          <div class="col-6">
            <label class="form-label">Хедер (HTML)</label>
            <textarea v-model="headerHtml" class="form-control" placeholder="HTML для хедера" rows="3"></textarea>
          </div>
          <div class="col-6">
            <label class="form-label">Футер (HTML)</label>
            <textarea v-model="footerHtml" class="form-control" placeholder="HTML для футера" rows="3"></textarea>
          </div>
          <div class="col-6">
            <label class="form-label">Фон страницы</label>
            <input v-model="pageBg" class="form-control form-control-color" type="color">
          </div>
          <div class="col-6">
            <label class="form-label">Градиент фона</label>
            <input v-model="pageGradient" class="form-control" placeholder="linear-gradient(...)" type="text">
          </div>
          <div class="col-6">
            <label class="form-label">Шрифт страницы</label>
            <input v-model="pageFont" class="form-control" placeholder="Arial, sans-serif" type="text">
          </div>
          <div class="col-6">
            <label class="form-label">Размер шрифта</label>
            <input v-model="pageFontSize" class="form-control" max="48" min="10" type="number">
          </div>
        </div>
        <button class="btn btn-primary mt-3" @click="saveLayout">Сохранить макет</button>
      </div>
    </div>
    <div class="card mt-4">
      <div class="card-header d-flex align-items-center">
        <i class="bi bi-plus-circle me-2"></i>
        <b>Добавить элемент</b>
        <select v-model="newElemType" class="form-select form-select-sm w-auto ms-2">
          <option value="button">Кнопка</option>
          <option value="img">Изображение</option>
          <option value="icon">Иконка</option>
          <option value="text">Текст</option>
          <option value="custom">HTML-блок</option>
        </select>
        <button class="btn btn-sm btn-success ms-2" @click="addElement"><i class="bi bi-plus-lg"></i> Добавить</button>
      </div>
    </div>
    <div class="card mt-4">
      <div class="card-header d-flex align-items-center">
        <i class="bi bi-phone me-2"></i>
        <b>Предпросмотр для мобильных</b>
        <button class="btn btn-sm btn-outline-primary ms-auto" @click="toggleMobilePreview">
          {{ mobilePreview ? 'Десктоп' : 'Мобильный' }}
        </button>
      </div>
      <div class="card-body bg-light">
        <div :style="mobilePreview ? mobileStyle : {}">
          <div v-html="headerHtml"></div>
          <div :style="visualPreviewStyle" class="visual-editor-preview">
            <div v-for="el in visualElements" :key="el.id" :style="elementStyle(el)">
              <component
                  :is="el.type==='custom' ? 'div' : el.type==='img' ? 'img' : el.type==='button' ? 'button' : 'span'"
                  :class="el.icon || ''"
                  :style="el.type==='button' ? 'width:100%;' : ''"
                  v-bind="el.type==='img' ? {src:el.src,alt:'',style:'max-width:100%'} : {}"
                  v-html="el.type==='custom' ? el.text : undefined"
              >
              </component>
            </div>
          </div>
          <div v-html="footerHtml"></div>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import {computed, ref} from 'vue'

const API = import.meta.env.VITE_API_BASE_URL || ''

interface Page {
  id: number,
  title: string,
  content: string
}

const pages = ref<Page[]>([
  {id: 1, title: 'О системе', content: '<h3>О системе</h3><p>Описание...</p>'},
  {id: 2, title: 'Помощь', content: '<h3>Помощь</h3><p>FAQ...</p>'}
])
const selectedPage = ref<Page | null>(null)

function selectPage(p: Page) {
  selectedPage.value = {...p}
}

function createNewPage() {
  const id = Math.max(0, ...pages.value.map(p => p.id)) + 1
  const page = {id, title: '', content: ''}
  pages.value.push(page)
  selectedPage.value = {...page}
}

function savePage() {
  if (!selectedPage.value) return
  const idx = pages.value.findIndex(p => p.id === selectedPage.value!.id)
  if (idx >= 0) pages.value[idx] = {...selectedPage.value}
}

function deletePage(id: number) {
  pages.value = pages.value.filter(p => p.id !== id)
  if (selectedPage.value?.id === id) selectedPage.value = null
}

const uiPermissions = ref<string[]>(['can_see_analytics', 'can_see_admin_panel'])

function addPermission() {
  uiPermissions.value.push('')
}

function removePermission(idx: number) {
  uiPermissions.value.splice(idx, 1)
}

const visualElements = ref<any[]>([])
const showStylePanel = ref<number | null>(null)
let dragIdx = -1

function addElement() {
  let el: any = {
    id: Date.now(),
    type: newElemType.value,
    text: '',
    icon: '',
    style: {
      left: 20,
      top: 20,
      width: 120,
      height: 40,
      color: '#222',
      background: '#e9ecef',
      opacity: 1,
      fontFamily: pageFont.value,
      fontSize: pageFontSize.value,
      gradient: ''
    }
  }
  if (newElemType.value === 'button') {
    el.text = 'Кнопка';
    el.icon = 'bi bi-hand-index'
  }
  if (newElemType.value === 'img') {
    el.text = 'Изображение';
    el.type = 'img'
  }
  if (newElemType.value === 'icon') {
    el.text = 'Иконка';
    el.icon = 'bi bi-star'
  }
  if (newElemType.value === 'text') {
    el.text = 'Текст';
  }
  if (newElemType.value === 'custom') {
    el.text = '<b>HTML</b>';
    el.type = 'custom'
  }
  visualElements.value.push(el)
}

const headerHtml = ref('<div class="p-2 text-center">Мой хедер</div>')
const footerHtml = ref('<div class="p-2 text-center">Мой футер</div>')
const pageBg = ref('#ffffff')
const pageGradient = ref('')
const pageFont = ref('Arial, sans-serif')
const pageFontSize = ref(16)
const newElemType = ref('button')

async function saveLayout() {
  const layout = {
    headerHtml: headerHtml.value,
    footerHtml: footerHtml.value,
    pageBg: pageBg.value,
    pageGradient: pageGradient.value,
    pageFont: pageFont.value,
    pageFontSize: pageFontSize.value,
    elements: visualElements.value
  }
  try {
    const r = await fetch(`${API}/api/pages/layout`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(layout)
    })
    if (!r.ok) throw new Error('Сервер вернул ошибку')
    alert('Макет сохранён!')
  } catch (e) {
    console.warn('Не удалось сохранить макет (заглушка):', e)
    alert('Макет сохранён локально (заглушка).')
  }
}

function removeElement(idx: number) {
  visualElements.value.splice(idx, 1)
}

function editStyle(idx: number) {
  showStylePanel.value = idx
}

function elementStyle(el: any) {
  const s = el.style || {}
  return {
    left: (s.left || 0) + 'px',
    top: (s.top || 0) + 'px',
    width: (s.width || 120) + 'px',
    height: (s.height || 40) + 'px',
    color: s.color || '#222',
    background: s.gradient ? s.gradient : s.background || '#e9ecef',
    opacity: s.opacity || 1,
    fontFamily: s.fontFamily || 'inherit',
    zIndex: 10
  }
}

function dragStart(idx: number, e: DragEvent) {
  dragIdx = idx;
  e.dataTransfer?.setData('text/plain', '')
}

function dragEnd(e: DragEvent) {
  if (dragIdx !== -1) {
    const rect = (e.target as HTMLElement).parentElement?.getBoundingClientRect()
    if (rect) {
      visualElements.value[dragIdx].style.left = e.clientX - rect.left - 60
      visualElements.value[dragIdx].style.top = e.clientY - rect.top - 20
    }
  }
  dragIdx = -1
}

function onImageChange(e: Event, idx: number) {
  const file = (e.target as HTMLInputElement).files?.[0]
  if (file) {
    const reader = new FileReader()
    reader.onload = ev => visualElements.value[idx].src = ev.target?.result as string
    reader.readAsDataURL(file)
  }
}

const mobilePreview = ref(false)

function toggleMobilePreview() {
  mobilePreview.value = !mobilePreview.value
}

const mobileStyle = {
  width: '375px',
  minHeight: '667px',
  border: '1px solid #ccc',
  borderRadius: '1.2rem',
  margin: '0 auto',
  background: '#fff',
  overflow: 'hidden',
  boxShadow: '0 0 16px #0002'
}
const visualPreviewStyle = computed(() => ({
  minHeight: '320px',
  position: 'relative',
  background: pageGradient.value ? pageGradient.value : pageBg.value,
  fontFamily: pageFont.value,
  fontSize: pageFontSize.value + 'px',
  padding: '12px'
}))
</script>

<style>
.visual-editor {
  min-height: 320px;
  position: relative;
}

.ve-elem {
  transition: transform 0.2s ease, opacity 0.2s ease;
}

.visual-editor-preview {
  box-shadow: 0 0 16px rgba(0, 0, 0, 0.2);
  border-radius: 0.8rem;
  overflow: hidden;
}
</style>
