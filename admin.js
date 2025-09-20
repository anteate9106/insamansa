// Admin Page JavaScript
// Supabase 설정 (실제 URL과 키로 교체 필요)
const SUPABASE_URL = 'YOUR_SUPABASE_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';

// Supabase 클라이언트 초기화 (오류 처리 포함)
let supabase;
try {
    if (SUPABASE_URL === 'YOUR_SUPABASE_URL' || SUPABASE_ANON_KEY === 'YOUR_SUPABASE_ANON_KEY') {
        console.warn('Supabase 설정이 필요합니다. admin.js 파일에서 SUPABASE_URL과 SUPABASE_ANON_KEY를 실제 값으로 교체하세요.');
        // 임시로 더미 객체 생성
        supabase = {
            from: () => ({
                select: () => ({ eq: () => ({ order: () => Promise.resolve({ data: [], error: null }) }) }),
                insert: () => ({ select: () => ({ single: () => Promise.resolve({ data: null, error: { message: 'Supabase 설정 필요' } }) }) }),
                delete: () => ({ eq: () => Promise.resolve({ error: { message: 'Supabase 설정 필요' } }) })
            })
        };
    } else {
        supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    }
} catch (error) {
    console.error('Supabase 초기화 오류:', error);
    // 오류 발생 시 더미 객체 사용
    supabase = {
        from: () => ({
            select: () => ({ eq: () => ({ order: () => Promise.resolve({ data: [], error: null }) }) }),
            insert: () => ({ select: () => ({ single: () => Promise.resolve({ data: null, error: { message: 'Supabase 설정 필요' } }) }) }),
            delete: () => ({ eq: () => Promise.resolve({ error: { message: 'Supabase 설정 필요' } }) })
        })
    };
}

// 전역 변수
let currentSection = 'dashboard';
let currentTestType = 'disc';

// 페이지 로드 시 초기화
document.addEventListener('DOMContentLoaded', function() {
    console.log('관리자 페이지가 로드되었습니다.');
    
    // 모달 요소 확인
    const modal = document.getElementById('add-question-modal');
    if (modal) {
        console.log('모달 요소 발견됨');
    } else {
        console.error('add-question-modal 요소를 찾을 수 없습니다.');
    }
    
    // 문제 추가 폼 확인
    const form = document.getElementById('add-question-form');
    if (form) {
        console.log('문제 추가 폼 발견됨');
        form.addEventListener('submit', handleAddQuestion);
    } else {
        console.error('add-question-form 요소를 찾을 수 없습니다.');
    }
    
    // 문제 추가 버튼들에 이벤트 리스너 추가
    const addButtons = document.querySelectorAll('button[data-test-type]');
    console.log('=== 문제 추가 버튼 설정 ===');
    console.log('문제 추가 버튼 개수:', addButtons.length);
    
    addButtons.forEach((button, index) => {
        console.log(`버튼 ${index + 1} 발견:`, button.textContent);
        console.log(`버튼 ${index + 1} data-test-type:`, button.getAttribute('data-test-type'));
        
        button.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            console.log('=== 버튼 클릭 이벤트 발생 ===');
            console.log('클릭된 버튼:', this.textContent);
            const testType = this.getAttribute('data-test-type') || 'disc';
            console.log('testType:', testType);
            openAddQuestionModal(testType);
        });
        
        console.log(`버튼 ${index + 1} 이벤트 리스너 추가 완료`);
    });
    
    console.log('=== 모든 버튼 설정 완료 ===');
    
    showAlert('관리자 페이지에 오신 것을 환영합니다!', 'success');
    
    // 초기 데이터 로드
    loadDashboardData();
    loadQuestions('disc');
});

// 섹션 표시
function showSection(sectionId) {
    // 모든 섹션 숨기기
    document.querySelectorAll('.content-section').forEach(section => {
        section.classList.remove('active');
    });
    
    // 모든 네비게이션 링크 비활성화
    document.querySelectorAll('.nav-link').forEach(link => {
        link.classList.remove('active');
    });
    
    // 선택된 섹션 표시
    document.getElementById(sectionId).classList.add('active');
    
    // 선택된 네비게이션 링크 활성화
    event.target.classList.add('active');
    
    currentSection = sectionId;
    
    // 섹션별 알림
    const sectionNames = {
        'dashboard': '대시보드',
        'users': '사용자 관리',
        'disc-questions': 'DiSC 문제 관리',
        'mbti-questions': 'MBTI 문제 관리',
        'stress-questions': '스트레스 문제 관리',
        'results': '검사 결과'
    };
    
    showAlert(`${sectionNames[sectionId]} 섹션으로 이동했습니다.`, 'success');
}

// 알림 표시
function showAlert(message, type) {
    const alertDiv = document.createElement('div');
    alertDiv.className = `alert alert-${type}`;
    alertDiv.textContent = message;
    
    const container = document.querySelector('.main-content');
    container.insertBefore(alertDiv, container.firstChild);
    
    setTimeout(() => {
        alertDiv.remove();
    }, 3000);
}

// 로그아웃
function logout() {
    if (confirm('정말로 로그아웃하시겠습니까?')) {
        showAlert('로그아웃되었습니다.', 'success');
        setTimeout(() => {
            window.location.href = 'index.html';
        }, 1000);
    }
}

// 대시보드 데이터 로드
async function loadDashboardData() {
    try {
        // 사용자 수
        const { count: userCount } = await supabase
            .from('profiles')
            .select('*', { count: 'exact', head: true });

        // 검사 결과 수
        const { count: testCount } = await supabase
            .from('results')
            .select('*', { count: 'exact', head: true });

        // 오늘 검사 수
        const today = new Date().toISOString().split('T')[0];
        const { count: todayCount } = await supabase
            .from('results')
            .select('*', { count: 'exact', head: true })
            .gte('created_at', today);

        // 문제 수
        const { count: questionCount } = await supabase
            .from('questions')
            .select('*', { count: 'exact', head: true });

        // 대시보드 업데이트
        document.getElementById('total-users').textContent = userCount || 0;
        document.getElementById('total-tests').textContent = testCount || 0;
        document.getElementById('today-tests').textContent = todayCount || 0;
        document.getElementById('total-questions').textContent = questionCount || 0;

    } catch (error) {
        console.error('대시보드 데이터 로드 오류:', error);
    }
}

// 문제 추가 모달 열기
function openAddQuestionModal(testType = 'disc') {
    console.log('=== openAddQuestionModal 호출됨 ===');
    console.log('testType:', testType);
    currentTestType = testType;
    
    const modal = document.getElementById('add-question-modal');
    console.log('모달 요소:', modal);
    
    if (modal) {
        console.log('모달 현재 display 값:', modal.style.display);
        modal.style.display = 'block';
        console.log('모달 display를 block으로 설정');
        console.log('모달 새로운 display 값:', modal.style.display);
        
        // 모달이 실제로 보이는지 확인
        setTimeout(() => {
            const computedStyle = window.getComputedStyle(modal);
            console.log('모달 computed display:', computedStyle.display);
            console.log('모달 computed visibility:', computedStyle.visibility);
            console.log('모달 computed opacity:', computedStyle.opacity);
        }, 100);
        
        resetAddQuestionForm();
        console.log('=== 모달 표시 완료 ===');
    } else {
        console.error('add-question-modal 요소를 찾을 수 없습니다.');
        alert('모달 요소를 찾을 수 없습니다. 페이지를 새로고침해주세요.');
    }
}

// 문제 추가 모달 닫기
function closeAddQuestionModal() {
    document.getElementById('add-question-modal').style.display = 'none';
}

// 문제 추가 폼 리셋
function resetAddQuestionForm() {
    document.getElementById('add-question-form').reset();
    const optionsContainer = document.getElementById('options-container');
    optionsContainer.innerHTML = `
        <div class="option-item">
            <input type="text" placeholder="선택지 1" class="option-text" required>
            <input type="number" placeholder="D" class="disc-score" min="0" max="10">
            <input type="number" placeholder="I" class="disc-score" min="0" max="10">
            <input type="number" placeholder="S" class="disc-score" min="0" max="10">
            <input type="number" placeholder="C" class="disc-score" min="0" max="10">
            <button type="button" class="remove-option-btn" onclick="removeOption(this)">삭제</button>
        </div>
        <div class="option-item">
            <input type="text" placeholder="선택지 2" class="option-text" required>
            <input type="number" placeholder="D" class="disc-score" min="0" max="10">
            <input type="number" placeholder="I" class="disc-score" min="0" max="10">
            <input type="number" placeholder="S" class="disc-score" min="0" max="10">
            <input type="number" placeholder="C" class="disc-score" min="0" max="10">
            <button type="button" class="remove-option-btn" onclick="removeOption(this)">삭제</button>
        </div>
    `;
}

// 선택지 추가
function addOption() {
    const optionsContainer = document.getElementById('options-container');
    const optionCount = optionsContainer.children.length + 1;
    
    const optionItem = document.createElement('div');
    optionItem.className = 'option-item';
    optionItem.innerHTML = `
        <input type="text" placeholder="선택지 ${optionCount}" class="option-text" required>
        <input type="number" placeholder="D" class="disc-score" min="0" max="10">
        <input type="number" placeholder="I" class="disc-score" min="0" max="10">
        <input type="number" placeholder="S" class="disc-score" min="0" max="10">
        <input type="number" placeholder="C" class="disc-score" min="0" max="10">
        <button type="button" class="remove-option-btn" onclick="removeOption(this)">삭제</button>
    `;
    
    optionsContainer.appendChild(optionItem);
}

// 선택지 삭제
function removeOption(button) {
    const optionsContainer = document.getElementById('options-container');
    if (optionsContainer.children.length > 2) {
        button.parentElement.remove();
    } else {
        alert('최소 2개의 선택지가 필요합니다.');
    }
}

// 문제 추가 처리
async function handleAddQuestion(e) {
    e.preventDefault();
    
    const questionText = document.getElementById('question-text').value.trim();
    if (!questionText) {
        alert('문제 내용을 입력해주세요.');
        return;
    }

    const options = [];
    const optionItems = document.querySelectorAll('.option-item');
    
    for (let i = 0; i < optionItems.length; i++) {
        const optionText = optionItems[i].querySelector('.option-text').value.trim();
        const discScores = Array.from(optionItems[i].querySelectorAll('.disc-score')).map(input => 
            parseInt(input.value) || 0
        );
        
        if (!optionText) {
            alert(`선택지 ${i + 1}의 내용을 입력해주세요.`);
            return;
        }
        
        options.push({
            option_text: optionText,
            disc_d: discScores[0],
            disc_i: discScores[1],
            disc_s: discScores[2],
            disc_c: discScores[3]
        });
    }

    try {
        // 문제 저장
        const { data: question, error: questionError } = await supabase
            .from('questions')
            .insert({
                test_type: currentTestType,
                question_text: questionText,
                question_order: 1 // 임시로 1로 설정, 실제로는 기존 문제 수 + 1
            })
            .select()
            .single();

        if (questionError) throw questionError;

        // 선택지 저장
        const optionsWithQuestionId = options.map(option => ({
            ...option,
            question_id: question.id
        }));

        const { error: optionsError } = await supabase
            .from('options')
            .insert(optionsWithQuestionId);

        if (optionsError) throw optionsError;

        alert('문제가 성공적으로 추가되었습니다.');
        closeAddQuestionModal();
        loadQuestions(currentTestType);
        loadDashboardData();

    } catch (error) {
        console.error('문제 추가 오류:', error);
        alert('문제 추가 중 오류가 발생했습니다: ' + error.message);
    }
}

// 문제 목록 로드
async function loadQuestions(testType = 'disc') {
    try {
        const { data, error } = await supabase
            .from('questions')
            .select(`
                *,
                options (*)
            `)
            .eq('test_type', testType)
            .order('question_order', { ascending: true });

        if (error) throw error;

        // 문제 목록을 테이블에 표시
        displayQuestions(data || [], testType);

    } catch (error) {
        console.error('문제 로드 오류:', error);
        showAlert('문제를 불러오는 중 오류가 발생했습니다.', 'error');
    }
}

// 문제 목록 표시
function displayQuestions(questions, testType) {
    const tableBody = document.querySelector(`#${testType}-questions .data-table tbody`);
    if (!tableBody) return;

    if (questions.length === 0) {
        tableBody.innerHTML = '<tr><td colspan="5" style="text-align: center;">등록된 문제가 없습니다.</td></tr>';
        return;
    }

    const html = questions.map((question, index) => `
        <tr>
            <td>${index + 1}</td>
            <td>${question.question_text}</td>
            <td>${question.options.length}개</td>
            <td>${new Date(question.created_at).toLocaleDateString()}</td>
            <td>
                <button class="btn btn-primary btn-sm" onclick="viewQuestion(${question.id})">보기</button>
                <button class="btn btn-warning btn-sm" onclick="editQuestion(${question.id})">수정</button>
                <button class="btn btn-danger btn-sm" onclick="deleteQuestion(${question.id})">삭제</button>
            </td>
        </tr>
    `).join('');

    tableBody.innerHTML = html;
}

// 문제 보기
function viewQuestion(questionId) {
    alert('문제 보기 기능은 추후 구현 예정입니다.');
}

// 문제 수정
function editQuestion(questionId) {
    alert('문제 수정 기능은 추후 구현 예정입니다.');
}

// 문제 삭제
async function deleteQuestion(questionId) {
    if (!confirm('정말로 이 문제를 삭제하시겠습니까?')) {
        return;
    }

    try {
        // 선택지 먼저 삭제
        const { error: optionsError } = await supabase
            .from('options')
            .delete()
            .eq('question_id', questionId);

        if (optionsError) throw optionsError;

        // 문제 삭제
        const { error: questionError } = await supabase
            .from('questions')
            .delete()
            .eq('id', questionId);

        if (questionError) throw questionError;

        alert('문제가 삭제되었습니다.');
        loadQuestions(currentTestType);
        loadDashboardData();

    } catch (error) {
        console.error('문제 삭제 오류:', error);
        alert('문제 삭제 중 오류가 발생했습니다: ' + error.message);
    }
}

// 사용자 목록 로드
async function loadUsers() {
    const usersSection = document.getElementById('users');
    usersSection.innerHTML = '<div class="loading">사용자 데이터를 불러오는 중...</div>';

    try {
        const { data, error } = await supabase
            .from('profiles')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) throw error;

        if (data && data.length > 0) {
            const html = `
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>이름</th>
                            <th>이메일</th>
                            <th>소속</th>
                            <th>가입일</th>
                            <th>관리자</th>
                            <th>액션</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${data.map(user => `
                            <tr>
                                <td>${user.name || '-'}</td>
                                <td>${user.email || '-'}</td>
                                <td>${user.organization || '-'}</td>
                                <td>${new Date(user.created_at).toLocaleDateString()}</td>
                                <td>${user.is_admin ? '예' : '아니오'}</td>
                                <td>
                                    <button class="btn btn-primary btn-sm">수정</button>
                                    <button class="btn btn-danger btn-sm">삭제</button>
                                </td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>
            `;
            usersSection.innerHTML = html;
        } else {
            usersSection.innerHTML = '<div class="loading">등록된 사용자가 없습니다.</div>';
        }

    } catch (error) {
        console.error('사용자 로드 오류:', error);
        usersSection.innerHTML = '<div class="error">사용자 데이터를 불러오는 중 오류가 발생했습니다.</div>';
    }
}

// 결과 목록 로드
async function loadResults() {
    const resultsSection = document.getElementById('results');
    resultsSection.innerHTML = '<div class="loading">결과 데이터를 불러오는 중...</div>';

    try {
        const { data, error } = await supabase
            .from('results')
            .select(`
                *,
                profiles (name, email)
            `)
            .order('created_at', { ascending: false });

        if (error) throw error;

        if (data && data.length > 0) {
            const html = `
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>사용자</th>
                            <th>검사 타입</th>
                            <th>결과</th>
                            <th>검사일</th>
                            <th>액션</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${data.map(result => `
                            <tr>
                                <td>${result.profiles?.name || '-'}</td>
                                <td>${result.test_type}</td>
                                <td>${result.result_data ? JSON.stringify(result.result_data) : '-'}</td>
                                <td>${new Date(result.created_at).toLocaleDateString()}</td>
                                <td>
                                    <button class="btn btn-primary btn-sm">상세보기</button>
                                    <button class="btn btn-danger btn-sm">삭제</button>
                                </td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>
            `;
            resultsSection.innerHTML = html;
        } else {
            resultsSection.innerHTML = '<div class="loading">검사 결과가 없습니다.</div>';
        }

    } catch (error) {
        console.error('결과 로드 오류:', error);
        resultsSection.innerHTML = '<div class="error">결과 데이터를 불러오는 중 오류가 발생했습니다.</div>';
    }
}

// 버튼 클릭 이벤트들
document.addEventListener('click', function(e) {
    if (e.target.classList.contains('btn')) {
        const buttonText = e.target.textContent;
        
        if (buttonText.includes('문제 추가')) {
            showAlert('문제 추가 기능은 추후 구현될 예정입니다.', 'success');
        } else if (buttonText.includes('새로고침')) {
            showAlert('데이터를 새로고침했습니다.', 'success');
        } else if (buttonText.includes('검색') || buttonText.includes('필터')) {
            showAlert('검색/필터 기능은 추후 구현될 예정입니다.', 'success');
        } else if (buttonText.includes('보기')) {
            showAlert('상세 보기 기능은 추후 구현될 예정입니다.', 'success');
        } else if (buttonText.includes('수정')) {
            showAlert('수정 기능은 추후 구현될 예정입니다.', 'success');
        } else if (buttonText.includes('삭제')) {
            if (confirm('정말로 삭제하시겠습니까?')) {
                showAlert('삭제되었습니다.', 'success');
            }
        }
    }
});

// 테스트 함수
function testModal() {
    console.log('=== 테스트 함수 호출됨 ===');
    alert('JavaScript가 작동합니다!');
    
    const modal = document.getElementById('add-question-modal');
    if (modal) {
        console.log('모달 요소 발견, 강제로 표시');
        modal.style.display = 'block';
        modal.style.backgroundColor = 'rgba(255,0,0,0.8)'; // 빨간색으로 표시
        setTimeout(() => {
            modal.style.display = 'none';
            modal.style.backgroundColor = 'rgba(0,0,0,0.5)';
        }, 3000);
    } else {
        console.error('모달 요소를 찾을 수 없음');
        alert('모달 요소를 찾을 수 없습니다!');
    }
}

// 모달 외부 클릭 시 닫기
window.onclick = function(event) {
    const modal = document.getElementById('add-question-modal');
    if (event.target === modal) {
        closeAddQuestionModal();
    }
}
