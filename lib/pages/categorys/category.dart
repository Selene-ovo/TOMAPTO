import 'package:flutter/material.dart';
import 'package:tomapto/widgets/navbar.dart';
import 'category_coffee.dart';
import 'category_restaurant.dart';
import 'category_gas.dart';
import 'category_store.dart';
import 'category_hos.dart';
import 'category_parking.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  void _onNavTap(int index) {
    // 네비게이션 탭 처리는 BottomNavBar 내부에서 이미 구현되어 있습니다
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final List<CategoryItem> categories = [
      CategoryItem(
        title: '카페',
        imagePath: 'assets/icons/category_coffee.png',
        categoryCode: 'CE7',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CategoryCoffeePage()),
          );
        },
      ),
      CategoryItem(
        title: '음식점',
        imagePath: 'assets/icons/category_restaurant.png',
        categoryCode: 'FD6',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CategoryRestaurantPage(),
            ),
          );
        },
      ),
      CategoryItem(
        title: '주유소',
        imagePath: 'assets/icons/category_gas.png',
        categoryCode: 'OL7',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CategoryGasPage()),
          );
        },
      ),
      CategoryItem(
        title: '편의점',
        imagePath: 'assets/icons/category_store.png',
        categoryCode: 'CS2',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CategoryStorePage()),
          );
        },
      ),
      CategoryItem(
        title: '병원',
        imagePath: 'assets/icons/category_hos.png',
        categoryCode: 'HP8',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CategoryHosPage()),
          );
        },
      ),
      CategoryItem(
        title: '주차장',
        imagePath: 'assets/icons/category_parking.png',
        categoryCode: 'PK6',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CategoryParkingPage(),
            ),
          );
        },
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          '카테고리',
          style: TextStyle(
            fontSize: 20 * (screenWidth / 375),
            fontWeight: FontWeight.w700,
            color: Colors.black,
            fontFamily: 'Pretendard',
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 20 * (screenWidth / 375),
              vertical: 16 * (screenHeight / 812),
            ),
            child: Row(
              children: [
                Text(
                  '가까운 곳 추천',
                  style: TextStyle(
                    fontSize: 20 * (screenWidth / 375),
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    fontFamily: 'Pretendard',
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '👍',
                  style: TextStyle(fontSize: 20 * (screenWidth / 375)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20 * (screenWidth / 375),
              ),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 16 * (screenWidth / 375),
                  mainAxisSpacing: 16 * (screenHeight / 812),
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return _buildCategoryCard(
                    category,
                    screenWidth,
                    screenHeight,
                  );
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 2, onTap: _onNavTap),
    );
  }

  Widget _buildCategoryCard(
    CategoryItem category,
    double screenWidth,
    double screenHeight,
  ) {
    return GestureDetector(
      onTap: category.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16 * (screenWidth / 375)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16 * (screenWidth / 375)),
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(category.imagePath),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32 * (screenWidth / 375)),
                color: const Color(0xFF252525).withOpacity(0.6),
              ),
              child: Center(
                child: Text(
                  category.title,
                  style: TextStyle(
                    fontSize: 26 * (screenWidth / 375),
                    fontWeight: FontWeight.w200,
                    color: Colors.white,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CategoryItem {
  final String title;
  final String imagePath;
  final String categoryCode;
  final VoidCallback onTap;

  CategoryItem({
    required this.title,
    required this.imagePath,
    required this.categoryCode,
    required this.onTap,
  });
}
