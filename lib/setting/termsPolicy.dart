// terms_policy.dart
import 'package:flutter/material.dart';

class TermsAndPolicyScreen extends StatelessWidget {
  const TermsAndPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '이용 약관 및 정책',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 1),
          
          // 서비스 이용약관 동의
          _buildListItem(
            context, 
            '서비스 이용약관 동의',
            _showServiceTermsModal,
          ),
          
          const SizedBox(height: 1),
          
          // 개인정보 수집 및 이용
          _buildListItem(
            context, 
            '개인정보 수집 및 이용',
            _showPrivacyPolicyModal,
          ),
          
          const SizedBox(height: 1),
          
          // 개인정보처리방침
          _buildListItem(
            context, 
            '개인정보처리방침',
            _showPrivacyHandlingModal,
          ),
          
          const SizedBox(height: 1),
          
          // 네이버 위치기반 서비스 이용약관
          _buildListItem(
            context, 
            '네이버 위치기반 서비스 이용약관',
            _showNaverLocationTermsModal,
          ),
          
          const SizedBox(height: 1),
          
          // 법적 공지 / 정보 제공처
          _buildListItem(
            context, 
            '법적 공지 / 정보 제공처',
            _showLegalNoticeModal,
          ),
        ],
      ),
    );
  }
  
  Widget _buildListItem(BuildContext context, String title, Function(BuildContext) onTap) {
    return Container(
      color: Colors.white,
      child: InkWell(
        onTap: () => onTap(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 서비스 이용약관 동의 모달
  void _showServiceTermsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '서비스 이용약관 동의',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: const [
                      Text(
                        '서비스 이용약관',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '제 1 조 (목적)\n'
                        '이 약관은 서비스 이용에 관한 기본적인 사항을 규정함을 목적으로 합니다.\n\n'
                        '제 2 조 (정의)\n'
                        '1. "서비스"라 함은 회사가 제공하는 위치기반 서비스, 지도 서비스 등을 말합니다.\n'
                        '2. "이용자"라 함은 회사가 제공하는 서비스를 이용하는 자를 말합니다.\n\n'
                        '제 3 조 (약관의 효력 및 변경)\n'
                        '1. 이 약관은 서비스를 이용하고자 하는 모든 이용자에게 적용됩니다.\n'
                        '2. 회사는 필요한 경우 약관을 변경할 수 있으며, 변경된 약관은 적용일 7일 전에 공지합니다.\n\n'
                        // 추가 내용 생략...
                        '본 약관은 2023년 1월 1일부터 시행됩니다.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  // 개인정보 수집 및 이용 모달
  void _showPrivacyPolicyModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '개인정보 수집 및 이용',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: const [
                      Text(
                        '개인정보 수집 및 이용 안내',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '1. 수집하는 개인정보 항목\n'
                        '- 위치정보: 현재 위치, 검색 위치, 경로 정보\n'
                        '- 기기정보: 기기 식별자, 운영체제 정보\n\n'
                        '2. 수집 및 이용 목적\n'
                        '- 위치기반 서비스 제공\n'
                        '- 서비스 개선 및 불편사항 해결\n\n'
                        '3. 보유 및 이용 기간\n'
                        '- 서비스 이용 종료 시까지 또는 법령에 따른 보관 기간\n\n'
                        '4. 동의 거부권 및 거부 시 불이익\n'
                        '- 개인정보 수집 및 이용에 대한 동의를 거부할 수 있으나, 서비스 이용이 제한될 수 있습니다.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  // 개인정보처리방침 모달
  void _showPrivacyHandlingModal(BuildContext context) {
    // 이전 모달과 유사한 형태로 구현
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '개인정보처리방침',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: const [
                      Text(
                        '개인정보처리방침',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '제1조(개인정보의 처리 목적)\n'
                        '회사는 다음의 목적을 위하여 개인정보를 처리합니다.\n'
                        '- 서비스 제공 및 개선\n'
                        '- 회원 관리 및 서비스 이용 지원\n'
                        '- 신규 서비스 개발 및 마케팅\n\n'
                        '제2조(개인정보의 처리 및 보유 기간)\n'
                        '회사는 법령에 따른 개인정보 보유·이용기간 또는 정보주체로부터 개인정보를 수집 시 동의 받은 개인정보 보유·이용기간 내에서 개인정보를 처리·보유합니다.\n\n'
                        '제3조(개인정보의 제3자 제공)\n'
                        '회사는 원칙적으로 이용자의 개인정보를 제1조(개인정보의 처리 목적)에서 명시한 범위 내에서 처리하며, 정보주체의 동의, 법률의 특별한 규정 등 「개인정보 보호법」 제17조 및 제18조에 해당하는 경우에만 개인정보를 제3자에게 제공합니다.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  // 네이버 위치기반 서비스 이용약관 모달
  void _showNaverLocationTermsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '네이버 위치기반 서비스 이용약관',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: const [
                      Text(
                        '네이버 위치기반서비스 이용약관',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '제 1 조 (목적)\n'
                        '이 약관은 네이버 주식회사(이하 "회사")가 제공하는 위치기반서비스(이하 "서비스")를 이용함에 있어 회사와 이용자의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.\n\n'
                        '제 2 조 (이용약관의 효력 및 변경)\n'
                        '① 본 약관은 서비스를 신청한 이용자 또는 개인위치정보주체가 본 약관에 동의하고 회사가 정한 소정의 절차에 따라 서비스의 이용자로 등록함으로써 효력이 발생합니다.\n'
                        '② 회사는 본 약관의 내용을 이용자가 쉽게 알 수 있도록 서비스 초기 화면에 게시하거나 기타의 방법으로 공지합니다.\n\n'
                        '제 3 조 (위치정보 수집방법)\n'
                        '회사는 다음과 같은 방식으로 개인위치정보를 수집합니다.\n'
                        '1. 휴대폰 등 이동단말기의 GPS 칩이 내장되어 있는 경우 GPS 정보를 수집\n'
                        '2. 기지국 정보를 수집\n'
                        '3. Wi-Fi 정보를 수집',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  // 법적 공지 / 정보 제공처 모달
  void _showLegalNoticeModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '법적 공지 / 정보 제공처',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: const [
                      Text(
                        '법적 공지',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '저작권 정보\n'
                        '본 애플리케이션에서 제공하는 모든 콘텐츠는 저작권법의 보호를 받습니다. 회사의 사전 동의 없이 무단 복제, 배포, 전송 등의 행위는 저작권법에 의해 금지됩니다.\n\n'
                        '지도 데이터 공지\n'
                        '© NAVER Corp.\n'
                        '네이버에서 제공하는 지도 서비스는 네이버의 사전 승인 없이 상업적 목적으로 이용할 수 없습니다.\n\n'
                        '정보 제공처\n'
                        '- 지도 데이터: 네이버 주식회사\n'
                        '- 교통 정보: 한국도로공사, 경찰청\n'
                        '- 대중교통 정보: 한국철도공사, 서울교통공사\n'
                        '- 날씨 정보: 기상청\n'
                        '- POI 정보: 네이버 주식회사, 각 정보 제공 업체',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}